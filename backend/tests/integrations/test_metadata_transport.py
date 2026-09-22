import asyncio
import ipaddress
import socket
import ssl
from datetime import UTC, datetime, timedelta

import httpcore
import httpx
import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID

from app.integrations.metadata_client import MetadataClient, UnsafeUrlError, _PinnedTransport

PUBLIC_IP = "93.184.216.34"
PUBLIC_IPV6 = "2606:4700:4700::1111"


async def public_resolver(host, port):
    return {PUBLIC_IP}


def html_response(*, location=None, cookie=None):
    body = b"<title>Public page</title>" if location is None else b""
    status = b"200 OK" if location is None else b"302 Found"
    headers = [b"Content-Type: text/html", f"Content-Length: {len(body)}".encode()]
    if location is not None:
        headers.append(f"Location: {location}".encode())
    if cookie is not None:
        headers.append(f"Set-Cookie: {cookie}".encode())
    return b"HTTP/1.1 " + status + b"\r\n" + b"\r\n".join(headers) + b"\r\n\r\n" + body


class RecordingStream(httpcore.AsyncMockStream):
    def __init__(self, *responses):
        super().__init__(list(responses))
        self.writes = []
        self.tls_names = []

    async def write(self, buffer, timeout=None):
        self.writes.append(buffer)

    async def start_tls(self, ssl_context, server_hostname=None, timeout=None):
        self.tls_names.append(server_hostname)
        return self


@pytest.mark.asyncio
async def test_default_transport_pins_ip_when_dns_changes_after_validation(monkeypatch):
    dns_calls = []
    connected_addresses = []
    stream = RecordingStream(html_response())

    def rebinding_dns(host, port, **kwargs):
        dns_calls.append(host)
        address = PUBLIC_IP if len(dns_calls) == 1 else "127.0.0.1"
        return [(socket.AF_INET, socket.SOCK_STREAM, socket.IPPROTO_TCP, "", (address, port))]

    async def connect(self, host, port, **kwargs):
        try:
            address = str(ipaddress.ip_address(host))
        except ValueError:
            address = next(iter(await MetadataClient._resolve_host(host, port)))
        connected_addresses.append(address)
        return stream

    monkeypatch.setattr(socket, "getaddrinfo", rebinding_dns)
    monkeypatch.setattr(httpcore.AnyIOBackend, "connect_tcp", connect)

    result = await MetadataClient().extract_from_url("https://example.test/post?x=1")

    assert result.status == "success"
    assert connected_addresses == [PUBLIC_IP]
    assert dns_calls == ["example.test"]
    assert stream.tls_names == ["example.test"]
    assert b"Host: example.test\r\n" in b"".join(stream.writes)
    assert result.resolved_url == "https://example.test/post?x=1"


@pytest.mark.asyncio
@pytest.mark.parametrize("scheme, port", [("http", 80), ("https", 443)])
async def test_pinned_connection_uses_default_port_and_ignores_environment_proxy(
    monkeypatch, scheme, port
):
    connections = []
    stream = RecordingStream(html_response())
    for name in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY"):
        monkeypatch.setenv(name, "http://127.0.0.1:3128")
    monkeypatch.setenv("NO_PROXY", "")

    async def connect(self, host, port, **kwargs):
        connections.append((host, port))
        return stream

    monkeypatch.setattr(httpcore.AnyIOBackend, "connect_tcp", connect)
    url = f"{scheme}://example.test:{port}/post"
    result = await MetadataClient(resolver=public_resolver).extract_from_url(url)

    assert result.status == "success"
    assert result.resolved_url == url
    assert connections == [(PUBLIC_IP, port)]
    assert b"Host: example.test\r\n" in b"".join(stream.writes)
    assert stream.tls_names == (["example.test"] if scheme == "https" else [])


@pytest.mark.asyncio
@pytest.mark.parametrize("target", ["/next", "https://other.test/next"])
async def test_redirect_revalidates_dns_before_connecting(monkeypatch, target):
    resolutions, connections = [], []

    async def resolver(host, port):
        resolutions.append(host)
        return {PUBLIC_IP} if len(resolutions) == 1 else {"127.0.0.1"}

    async def connect(self, host, port, **kwargs):
        connections.append(host)
        return RecordingStream(html_response(location=target))

    monkeypatch.setattr(httpcore.AnyIOBackend, "connect_tcp", connect)
    with pytest.raises(UnsafeUrlError):
        await MetadataClient(resolver=resolver).extract_from_url("https://example.test/start")

    assert len(resolutions) == 2
    assert connections == [PUBLIC_IP]


@pytest.mark.asyncio
async def test_redirects_preserve_url_cookie_scope_and_separate_tls_connections(monkeypatch):
    streams, hosts = [], []
    responses = [
        html_response(location="/next", cookie="session=first; Path=/"),
        html_response(location="https://second.test/final"),
        html_response(),
    ]

    async def connect(self, host, port, **kwargs):
        hosts.append(host)
        stream = RecordingStream(responses[len(streams)])
        streams.append(stream)
        return stream

    monkeypatch.setattr(httpcore.AnyIOBackend, "connect_tcp", connect)
    result = await MetadataClient(resolver=public_resolver).extract_from_url(
        "https://first.test/start"
    )

    assert result.status == "success"
    assert result.resolved_url == "https://second.test/final"
    assert hosts == [PUBLIC_IP] * 3
    assert [s.tls_names for s in streams] == [["first.test"], ["first.test"], ["second.test"]]
    assert b"GET /next HTTP/1.1" in b"".join(streams[1].writes)
    assert b"Cookie: session=first\r\n" in b"".join(streams[1].writes)
    assert b"cookie:" not in b"".join(streams[2].writes).lower()


@pytest.mark.asyncio
async def test_concurrent_extractions_keep_their_own_addresses(monkeypatch):
    expected = {"first.test": PUBLIC_IP, "second.test": PUBLIC_IPV6}
    connections = []

    async def resolver(host, port):
        await asyncio.sleep(0)
        return {expected[host]}

    async def connect(self, host, port, **kwargs):
        stream = RecordingStream(html_response())
        connections.append((host, stream))
        return stream

    monkeypatch.setattr(httpcore.AnyIOBackend, "connect_tcp", connect)
    client = MetadataClient(resolver=resolver)
    results = await asyncio.gather(
        *(client.extract_from_url(f"https://{host}/") for host in expected)
    )

    assert all(result.status == "success" for result in results)
    assert {s.tls_names[0]: address for address, s in connections} == expected


@pytest.mark.asyncio
@pytest.mark.parametrize("failure", [httpcore.ConnectError, httpcore.ConnectTimeout])
async def test_connection_failure_tries_only_remaining_validated_ips(monkeypatch, failure):
    calls = []

    async def resolver(host, port):
        return {PUBLIC_IPV6, PUBLIC_IP}

    async def connect(self, host, port, timeout=None, **kwargs):
        calls.append((host, timeout))
        if host == PUBLIC_IP:
            raise failure("injected connection failure")
        return RecordingStream(html_response())

    monkeypatch.setattr(httpcore.AnyIOBackend, "connect_tcp", connect)
    result = await MetadataClient(resolver=resolver).extract_from_url("https://example.test/")

    assert result.status == "success"
    assert [host for host, _ in calls] == [PUBLIC_IP, PUBLIC_IPV6]
    assert 0 < calls[0][1] <= 2.5
    assert 0 < calls[1][1] <= 5


@pytest.mark.asyncio
async def test_total_deadline_covers_all_connection_attempts(monkeypatch):
    calls = []

    async def resolver(host, port):
        return {PUBLIC_IP, PUBLIC_IPV6}

    async def connect(self, host, port, timeout=None, **kwargs):
        calls.append((host, timeout))
        if len(calls) == 1:
            await asyncio.sleep(timeout)
            raise httpcore.ConnectTimeout("first address timed out")
        await asyncio.sleep(1)
        raise AssertionError("The total deadline must cancel the second attempt")

    monkeypatch.setattr(httpcore.AnyIOBackend, "connect_tcp", connect)
    async with asyncio.timeout(0.5):
        result = await MetadataClient(
            resolver=resolver, total_timeout_seconds=0.1
        ).extract_from_url("https://example.test/")

    assert result.failure_reason == "timeout"
    assert [host for host, _ in calls] == [PUBLIC_IP, PUBLIC_IPV6]
    assert all(0 < timeout <= 0.051 for _, timeout in calls)


@pytest.mark.asyncio
async def test_read_failure_does_not_replay_request_to_another_ip(monkeypatch):
    calls = []

    class FailingStream(RecordingStream):
        async def read(self, max_bytes, timeout=None):
            raise httpcore.ReadTimeout("injected response timeout")

    async def resolver(host, port):
        return {PUBLIC_IP, PUBLIC_IPV6}

    async def connect(self, host, port, **kwargs):
        calls.append(host)
        return FailingStream()

    monkeypatch.setattr(httpcore.AnyIOBackend, "connect_tcp", connect)
    result = await MetadataClient(resolver=resolver).extract_from_url("https://example.test/")

    assert result.failure_reason == "request_failure"
    assert calls == [PUBLIC_IP]


@pytest.mark.asyncio
async def test_transport_rejects_requests_without_validated_addresses():
    calls = []

    def handle(request):
        calls.append(request)
        return httpx.Response(200)

    async with _PinnedTransport(httpx.MockTransport(handle)) as transport:
        with pytest.raises(UnsafeUrlError):
            await transport.handle_async_request(httpx.Request("GET", "https://example.test/"))

    assert calls == []


@pytest.fixture
def tls_certificate(tmp_path):
    key = ec.generate_private_key(ec.SECP256R1())
    subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "example.test")])
    now = datetime.now(UTC)
    certificate = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(subject)
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - timedelta(days=1))
        .not_valid_after(now + timedelta(days=1))
        .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
        .add_extension(x509.SubjectAlternativeName([x509.DNSName("example.test")]), critical=False)
        .sign(key, hashes.SHA256())
    )
    cert_path, key_path = tmp_path / "cert.pem", tmp_path / "key.pem"
    cert_path.write_bytes(certificate.public_bytes(serialization.Encoding.PEM))
    key_path.write_bytes(
        key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption(),
        )
    )
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(cert_path, key_path)
    return context, cert_path


@pytest.mark.asyncio
@pytest.mark.parametrize("case", ["valid", "wrong-host", "untrusted", "redirect-wrong-host"])
async def test_real_tls_verifies_original_hostname_and_certificate(
    monkeypatch, tls_certificate, case
):
    context, cert_path = tls_certificate
    server_names, requests, connections, active = [], [], [], set()
    context.set_servername_callback(lambda socket, name, ctx: server_names.append(name))

    async def serve(reader, writer):
        task = asyncio.current_task()
        active.add(task)
        try:
            while True:
                request = await reader.readuntil(b"\r\n\r\n")
                requests.append(request)
                location = (
                    "https://other.test/next"
                    if case == "redirect-wrong-host" and b"Host: example.test\r\n" in request
                    else None
                )
                writer.write(html_response(location=location))
                await writer.drain()
        except (asyncio.IncompleteReadError, ConnectionError):
            pass
        finally:
            writer.close()
            await writer.wait_closed()
            active.remove(task)

    real_context = ssl.create_default_context

    def trusted_context(*args, **kwargs):
        result = real_context(*args, **kwargs)
        if case != "untrusted":
            result.load_verify_locations(cafile=cert_path)
        return result

    monkeypatch.setattr(ssl, "create_default_context", trusted_context)
    server = await asyncio.start_server(serve, "127.0.0.1", 0, ssl=context)
    server_port = server.sockets[0].getsockname()[1]
    real_connect = httpcore.AnyIOBackend.connect_tcp

    async def connect(self, host, port, **kwargs):
        connections.append(host)
        assert host == PUBLIC_IP
        # Only tests map the validated public IP to this isolated TLS fixture.
        return await real_connect(self, "127.0.0.1", server_port, **kwargs)

    monkeypatch.setattr(httpcore.AnyIOBackend, "connect_tcp", connect)
    host = "other.test" if case == "wrong-host" else "example.test"
    try:
        result = await MetadataClient(resolver=public_resolver).extract_from_url(f"https://{host}/")
    finally:
        server.close()
        await server.wait_closed()
        if active:
            await asyncio.wait_for(asyncio.gather(*active), 2)

    if case == "valid":
        assert result.status == "success"
        assert len(requests) == 1
        assert server_names == ["example.test"]
    else:
        assert result.failure_reason == "request_failure"
        assert len(requests) == (1 if case == "redirect-wrong-host" else 0)
    if case == "redirect-wrong-host":
        assert connections == [PUBLIC_IP, PUBLIC_IP]
        assert server_names == ["example.test", "other.test"]

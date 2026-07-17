from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from html import unescape
import ipaddress
import socket
from urllib.parse import urljoin, urlparse, urlunparse

from bs4 import BeautifulSoup
import httpx


HTML_CONTENT_TYPES = {"text/html", "application/xhtml+xml"}
REDIRECT_STATUS_CODES = {301, 302, 303, 307, 308}
INTERNAL_HOST_SUFFIXES = (".localhost", ".local", ".internal", ".home", ".lan")


class UnsafeUrlError(ValueError):
    pass


class UrlResolutionError(RuntimeError):
    pass


@dataclass(frozen=True)
class MetadataResult:
    resolved_url: str
    title: str | None
    description: str | None
    status: str
    failure_reason: str | None = None


Resolver = Callable[[str, int], Awaitable[set[str]]]


class MetadataClient:
    def __init__(
        self,
        *,
        total_timeout_seconds: float = 5.0,
        max_redirects: int = 3,
        max_response_bytes: int = 1_000_000,
        user_agent: str = "ClipbackBot/0.1",
        http_client: httpx.AsyncClient | None = None,
        resolver: Resolver | None = None,
    ) -> None:
        self.total_timeout_seconds = total_timeout_seconds
        self.max_redirects = max_redirects
        self.max_response_bytes = max_response_bytes
        self.user_agent = user_agent
        self.http_client = http_client
        self.resolver = resolver or self._resolve_host

    async def extract_from_url(self, url: str) -> MetadataResult:
        initial_url = self._strip_fragment(url)
        current_url = initial_url
        last_safe_url = [initial_url]

        try:
            async with asyncio.timeout(self.total_timeout_seconds):
                if self.http_client is not None:
                    return await self._extract(self.http_client, current_url, last_safe_url)

                timeout = httpx.Timeout(self.total_timeout_seconds)
                async with httpx.AsyncClient(
                    follow_redirects=False,
                    timeout=timeout,
                    headers={"User-Agent": self.user_agent},
                    trust_env=False,
                ) as client:
                    return await self._extract(client, current_url, last_safe_url)
        except UnsafeUrlError:
            raise
        except TimeoutError:
            return self._failure(last_safe_url[0], "timeout")
        except UrlResolutionError:
            return self._failure(last_safe_url[0], "dns_failure")
        except httpx.HTTPError:
            return self._failure(last_safe_url[0], "request_failure")
        except Exception:
            return self._failure(last_safe_url[0], "parse_failure")

    async def _extract(
        self,
        client: httpx.AsyncClient,
        initial_url: str,
        last_safe_url: list[str],
    ) -> MetadataResult:
        current_url = initial_url

        for redirect_count in range(self.max_redirects + 1):
            current_url = await self._validate_url(current_url)
            last_safe_url[0] = current_url
            async with client.stream(
                "GET",
                current_url,
                headers={"User-Agent": self.user_agent},
                follow_redirects=False,
            ) as response:
                if response.status_code in REDIRECT_STATUS_CODES:
                    location = response.headers.get("location")
                    if location is None:
                        return self._failure(current_url, "redirect_without_location")
                    if redirect_count >= self.max_redirects:
                        return self._failure(current_url, "redirect_limit")
                    current_url = self._strip_fragment(urljoin(current_url, location))
                    continue

                if not 200 <= response.status_code < 300:
                    return self._failure(current_url, f"http_status_{response.status_code}")

                content_type = (
                    response.headers.get("content-type", "").split(";", 1)[0].strip().lower()
                )
                if content_type not in HTML_CONTENT_TYPES:
                    return self._failure(current_url, "non_html")

                body = bytearray()
                async for chunk in response.aiter_bytes():
                    body.extend(chunk)
                    if len(body) > self.max_response_bytes:
                        return self._failure(current_url, "response_too_large")

                title, description = self._parse_metadata(bytes(body), response.encoding)
                if title is None and description is None:
                    return self._failure(current_url, "metadata_missing")
                return MetadataResult(
                    resolved_url=current_url,
                    title=title,
                    description=description,
                    status="success",
                )

        return self._failure(current_url, "redirect_limit")

    async def _validate_url(self, url: str) -> str:
        normalized_url = self._strip_fragment(url)
        try:
            parsed = urlparse(normalized_url)
            port = parsed.port
        except ValueError as exc:
            raise UnsafeUrlError("Invalid URL port") from exc

        if parsed.scheme not in {"http", "https"}:
            raise UnsafeUrlError("Only HTTP and HTTPS URLs are supported")
        if not parsed.hostname:
            raise UnsafeUrlError("URL hostname is required")
        if parsed.username is not None or parsed.password is not None:
            raise UnsafeUrlError("URL credentials are not supported")

        expected_port = 80 if parsed.scheme == "http" else 443
        if port is not None and port != expected_port:
            raise UnsafeUrlError("Only default HTTP and HTTPS ports are supported")

        hostname = parsed.hostname.rstrip(".").lower()
        if self._is_internal_hostname(hostname):
            raise UnsafeUrlError("Internal hostnames are not supported")

        try:
            addresses = {str(ipaddress.ip_address(hostname))}
        except ValueError:
            addresses = await self.resolver(hostname, expected_port)

        if not addresses:
            raise UrlResolutionError("URL hostname did not resolve")
        if any(self._is_unsafe_address(address) for address in addresses):
            raise UnsafeUrlError("Private or internal network addresses are not supported")

        return normalized_url

    @staticmethod
    async def _resolve_host(hostname: str, port: int) -> set[str]:
        try:
            records = await asyncio.to_thread(
                socket.getaddrinfo,
                hostname,
                port,
                type=socket.SOCK_STREAM,
            )
        except socket.gaierror as exc:
            raise UrlResolutionError("URL hostname could not be resolved") from exc
        return {record[4][0] for record in records}

    @staticmethod
    def _is_internal_hostname(hostname: str) -> bool:
        return (
            hostname == "localhost"
            or "." not in hostname
            or hostname.endswith(INTERNAL_HOST_SUFFIXES)
        )

    @staticmethod
    def _is_unsafe_address(address: str) -> bool:
        parsed = ipaddress.ip_address(address)
        return (
            not parsed.is_global
            or parsed.is_loopback
            or parsed.is_private
            or parsed.is_link_local
            or parsed.is_multicast
            or parsed.is_reserved
            or parsed.is_unspecified
        )

    @classmethod
    def _parse_metadata(
        cls,
        body: bytes,
        encoding: str | None,
    ) -> tuple[str | None, str | None]:
        text = body.decode(encoding or "utf-8", errors="replace")
        soup = BeautifulSoup(text, "html.parser")

        properties: dict[str, str] = {}
        names: dict[str, str] = {}
        for tag in soup.find_all("meta"):
            content = tag.get("content")
            if not isinstance(content, str):
                continue
            property_name = tag.get("property")
            name = tag.get("name")
            if isinstance(property_name, str):
                properties.setdefault(property_name.lower(), content)
            if isinstance(name, str):
                names.setdefault(name.lower(), content)

        html_title = soup.title.get_text(" ", strip=True) if soup.title else None
        title = cls._first_text(
            properties.get("og:title"),
            names.get("twitter:title"),
            html_title,
            max_length=120,
        )
        description = cls._first_text(
            properties.get("og:description"),
            names.get("twitter:description"),
            names.get("description"),
            max_length=500,
        )
        return title, description

    @classmethod
    def _first_text(cls, *values: str | None, max_length: int) -> str | None:
        for value in values:
            normalized = cls._normalize_text(value, max_length=max_length)
            if normalized:
                return normalized
        return None

    @staticmethod
    def _normalize_text(value: str | None, *, max_length: int) -> str | None:
        if value is None:
            return None
        normalized = " ".join(unescape(value).split())
        return normalized[:max_length] or None

    @staticmethod
    def _strip_fragment(url: str) -> str:
        parsed = urlparse(url.strip())
        return urlunparse(parsed._replace(fragment=""))

    @staticmethod
    def _failure(resolved_url: str, reason: str) -> MetadataResult:
        return MetadataResult(
            resolved_url=resolved_url,
            title=None,
            description=None,
            status="failed",
            failure_reason=reason,
        )

"""Unit HTTP/provider tests replace DB admission; integration tests never use this."""

from contextlib import asynccontextmanager


class OpenUnitGate:
    @asynccontextmanager
    async def operation(self, kind):
        yield

    async def status(self):
        return {"phase": "open"}


def control_schema_sql():
    """Add the current control schema to old synthetic minimal-business Docker fixtures."""
    from sqlalchemy.dialects import postgresql
    from sqlalchemy.schema import CreateTable

    from app.models.maintenance import MaintenanceEvent, MaintenanceOperation, MaintenanceState

    tables = [
        MaintenanceState.__table__,
        MaintenanceOperation.__table__,
        MaintenanceEvent.__table__,
    ]
    return ";".join(
        str(CreateTable(table).compile(dialect=postgresql.dialect())) for table in tables
    ) + (";INSERT INTO maintenance_state(id,phase,generation) VALUES(1,'open',0);")

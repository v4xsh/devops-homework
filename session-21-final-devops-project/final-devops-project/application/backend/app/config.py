"""Runtime configuration (12-factor): everything comes from environment variables.

In Kubernetes the non-secret values come from a ConfigMap and DB_PASSWORD from a Secret.
DATABASE_URL, if set, wins over the individual DB_* parts (used by tests and docker-compose).
"""
from urllib.parse import quote_plus

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "TaskBoard API"
    app_version: str = "1.0.1"
    app_env: str = "dev"
    log_level: str = "INFO"

    database_url: str | None = None
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "taskboard"
    db_user: str = "taskboard"
    db_password: str = ""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def sqlalchemy_url(self) -> str:
        if self.database_url:
            return self.database_url
        return (
            f"postgresql+psycopg://{quote_plus(self.db_user)}:{quote_plus(self.db_password)}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )


settings = Settings()

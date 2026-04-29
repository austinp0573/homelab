#!/usr/bin/env python3
import os
import secrets
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from werkzeug.security import generate_password_hash


DB_PATH = Path("/app/nutify/instance/nutify.db.sqlite")
TOKEN_PATH = Path("/app/nutify/instance/nut_event_api_token")
INSTANCE_DIR = Path("/app/nutify/instance")

EVENT_TYPES = (
    "ONLINE",
    "ONBATT",
    "LOWBATT",
    "COMMOK",
    "COMMBAD",
    "SHUTDOWN",
    "REPLBATT",
    "NOCOMM",
    "NOPARENT",
)


def env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, default)
    if value is None or value == "":
        raise SystemExit(f"[db-init] Missing required environment variable: {name}")
    return value


def now() -> str:
    return datetime.now(timezone.utc).replace(tzinfo=None).isoformat(sep=" ", timespec="microseconds")


def ensure_token() -> None:
    if TOKEN_PATH.exists():
        print("[db-init] Existing nut_event_api_token found")
        return

    TOKEN_PATH.write_text(secrets.token_hex(16), encoding="utf-8")
    os.chmod(TOKEN_PATH, 0o600)
    print("[db-init] Generated nut_event_api_token")


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS nutify_master_control (
            id INTEGER NOT NULL,
            server_name VARCHAR(100) NOT NULL,
            monitoring_profile VARCHAR(20) NOT NULL,
            is_configured BOOLEAN NOT NULL,
            created_at DATETIME,
            updated_at DATETIME,
            PRIMARY KEY (id)
        );

        CREATE TABLE IF NOT EXISTS orm_login (
            id INTEGER NOT NULL,
            username VARCHAR(100) NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            is_active BOOLEAN,
            is_admin BOOLEAN,
            role VARCHAR(20),
            permissions TEXT,
            options_tabs TEXT,
            last_login DATETIME,
            created_at DATETIME,
            updated_at DATETIME,
            PRIMARY KEY (id),
            UNIQUE (username)
        );

        CREATE TABLE IF NOT EXISTS ups_monitor_targets (
            id INTEGER NOT NULL,
            name VARCHAR(120) NOT NULL,
            ups_name VARCHAR(120) NOT NULL,
            host VARCHAR(255) NOT NULL,
            port INTEGER NOT NULL,
            nut_mode VARCHAR(20) NOT NULL,
            command_path VARCHAR(255) NOT NULL,
            source VARCHAR(30) NOT NULL,
            enabled BOOLEAN NOT NULL,
            is_primary BOOLEAN NOT NULL,
            location_enabled BOOLEAN NOT NULL,
            location VARCHAR(255) NOT NULL,
            location_country VARCHAR(120) NOT NULL,
            location_region VARCHAR(120) NOT NULL,
            location_city VARCHAR(120) NOT NULL,
            location_postal_code VARCHAR(40) NOT NULL,
            location_address VARCHAR(255) NOT NULL,
            location_latitude FLOAT,
            location_longitude FLOAT,
            last_test_status BOOLEAN,
            last_test_error TEXT,
            created_at DATETIME,
            updated_at DATETIME,
            PRIMARY KEY (id),
            UNIQUE (name)
        );

        CREATE TABLE IF NOT EXISTS ups_monitor_policies (
            id INTEGER NOT NULL,
            target_id INTEGER NOT NULL,
            db_strategy VARCHAR(20) NOT NULL,
            shard_granularity VARCHAR(10) NOT NULL,
            separate_db_path VARCHAR(255),
            polling_interval INTEGER NOT NULL,
            retention_days INTEGER NOT NULL,
            notify_scope VARCHAR(20) NOT NULL,
            last_polled_at DATETIME,
            last_success_at DATETIME,
            last_error TEXT,
            created_at DATETIME,
            updated_at DATETIME,
            PRIMARY KEY (id),
            FOREIGN KEY(target_id) REFERENCES ups_monitor_targets (id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS ups_monitor_target_profiles (
            id INTEGER NOT NULL,
            target_id INTEGER NOT NULL,
            input_sensitivity VARCHAR(255),
            device_model VARCHAR(255),
            device_serial VARCHAR(255),
            device_mfr VARCHAR(255),
            battery_type VARCHAR(255),
            battery_date VARCHAR(255),
            battery_mfr_date VARCHAR(255),
            created_at DATETIME,
            updated_at DATETIME,
            PRIMARY KEY (id),
            CONSTRAINT uq_target_profile_target UNIQUE (target_id),
            FOREIGN KEY(target_id) REFERENCES ups_monitor_targets (id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS ups_opt_variable_config (
            id INTEGER NOT NULL,
            target_id INTEGER,
            timezone VARCHAR(64),
            ups_realpower_nominal INTEGER,
            currency VARCHAR(3) NOT NULL,
            price_per_kwh FLOAT NOT NULL,
            co2_factor FLOAT NOT NULL,
            polling_interval INTEGER NOT NULL,
            measured_power_metric_key VARCHAR(120) NOT NULL,
            load_metric_key VARCHAR(120) NOT NULL,
            nominal_power_metric_key VARCHAR(120) NOT NULL,
            realpower_formula VARCHAR(260) NOT NULL,
            power_calibration_factor FLOAT NOT NULL,
            energy_formula VARCHAR(260) NOT NULL,
            cost_formula VARCHAR(260) NOT NULL,
            co2_formula VARCHAR(260) NOT NULL,
            created_at DATETIME,
            updated_at DATETIME,
            PRIMARY KEY (id)
        );

        CREATE TABLE IF NOT EXISTS ups_opt_notification (
            id INTEGER NOT NULL,
            target_id INTEGER,
            event_type VARCHAR(50) NOT NULL,
            enabled BOOLEAN,
            id_email INTEGER,
            ntfy_enabled BOOLEAN,
            id_ntfy INTEGER,
            telegram_enabled BOOLEAN,
            id_telegram INTEGER,
            webhook_enabled BOOLEAN,
            id_webhook INTEGER,
            created_at DATETIME,
            updated_at DATETIME,
            PRIMARY KEY (id),
            CONSTRAINT uq_notification_target_event UNIQUE (target_id, event_type)
        );

        CREATE TABLE IF NOT EXISTS ups_events (
            id INTEGER NOT NULL,
            timestamp_utc DATETIME NOT NULL,
            timestamp_utc_begin DATETIME,
            timestamp_utc_end DATETIME,
            ups_name VARCHAR(255),
            event_type VARCHAR(50),
            event_message TEXT,
            source_ip VARCHAR(45),
            acknowledged BOOLEAN,
            target_id INTEGER,
            PRIMARY KEY (id)
        );

        CREATE TABLE IF NOT EXISTS ups_monitor_data (
            id INTEGER NOT NULL,
            target_id INTEGER NOT NULL,
            timestamp_utc DATETIME NOT NULL,
            shard_key VARCHAR(20),
            ups_status VARCHAR(255),
            ups_load FLOAT,
            ups_power FLOAT,
            ups_power_nominal FLOAT,
            ups_realpower FLOAT,
            ups_realpower_nominal FLOAT,
            battery_charge FLOAT,
            battery_charge_low FLOAT,
            battery_charge_warning FLOAT,
            battery_runtime FLOAT,
            battery_runtime_low FLOAT,
            battery_voltage FLOAT,
            battery_voltage_nominal FLOAT,
            battery_current FLOAT,
            battery_temperature FLOAT,
            battery_alarm_threshold FLOAT,
            input_voltage FLOAT,
            input_voltage_nominal FLOAT,
            input_transfer_low FLOAT,
            input_transfer_high FLOAT,
            input_sensitivity VARCHAR(255),
            input_current FLOAT,
            input_frequency FLOAT,
            input_frequency_nominal FLOAT,
            output_voltage FLOAT,
            output_voltage_nominal FLOAT,
            output_current FLOAT,
            output_frequency FLOAT,
            output_frequency_nominal FLOAT,
            device_model VARCHAR(255),
            device_serial VARCHAR(255),
            device_mfr VARCHAR(255),
            battery_type VARCHAR(255),
            battery_date VARCHAR(255),
            battery_mfr_date VARCHAR(255),
            data_json TEXT,
            raw_json TEXT,
            created_at DATETIME,
            PRIMARY KEY (id),
            FOREIGN KEY(target_id) REFERENCES ups_monitor_targets (id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS ups_monitor_rollups (
            id INTEGER NOT NULL,
            target_id INTEGER NOT NULL,
            granularity VARCHAR(10) NOT NULL,
            bucket_start_utc DATETIME NOT NULL,
            bucket_end_utc DATETIME NOT NULL,
            sample_count INTEGER NOT NULL,
            ups_load FLOAT,
            ups_power FLOAT,
            ups_realpower FLOAT,
            ups_realpower_nominal FLOAT,
            battery_charge FLOAT,
            battery_runtime FLOAT,
            battery_voltage FLOAT,
            battery_temperature FLOAT,
            input_voltage FLOAT,
            output_voltage FLOAT,
            input_transfer_low FLOAT,
            input_transfer_high FLOAT,
            created_at DATETIME,
            updated_at DATETIME,
            PRIMARY KEY (id),
            CONSTRAINT uq_rollup_target_gran_bucket UNIQUE (target_id, granularity, bucket_start_utc),
            FOREIGN KEY(target_id) REFERENCES ups_monitor_targets (id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS ups_monitor_variable_mappings (
            id INTEGER NOT NULL,
            target_id INTEGER NOT NULL,
            canonical_key VARCHAR(128) NOT NULL,
            source_key VARCHAR(128) NOT NULL,
            mapping_mode VARCHAR(20) NOT NULL,
            is_enabled BOOLEAN NOT NULL,
            created_at DATETIME,
            updated_at DATETIME,
            PRIMARY KEY (id),
            CONSTRAINT uq_target_canonical_mapping UNIQUE (target_id, canonical_key),
            FOREIGN KEY(target_id) REFERENCES ups_monitor_targets (id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS ups_opt_mail_config (
            id INTEGER NOT NULL,
            target_id INTEGER,
            smtp_server VARCHAR(255) NOT NULL,
            smtp_port INTEGER NOT NULL,
            username VARCHAR(255),
            password BLOB,
            enabled BOOLEAN,
            provider VARCHAR(50),
            tls BOOLEAN,
            tls_starttls BOOLEAN,
            render_mode VARCHAR(20) NOT NULL,
            is_default BOOLEAN,
            to_email VARCHAR(255),
            from_email VARCHAR(255),
            created_at DATETIME,
            updated_at DATETIME,
            PRIMARY KEY (id)
        );

        CREATE TABLE IF NOT EXISTS ups_opt_ntfy (
            id INTEGER NOT NULL,
            target_id INTEGER,
            server_type VARCHAR(50) NOT NULL,
            server VARCHAR(255) NOT NULL,
            topic BLOB,
            use_auth BOOLEAN,
            username BLOB,
            password BLOB,
            priority INTEGER,
            use_tags BOOLEAN,
            render_mode VARCHAR(20) NOT NULL,
            is_default BOOLEAN,
            notify_onbatt BOOLEAN,
            notify_online BOOLEAN,
            notify_lowbatt BOOLEAN,
            notify_commok BOOLEAN,
            notify_commbad BOOLEAN,
            notify_shutdown BOOLEAN,
            notify_replbatt BOOLEAN,
            notify_nocomm BOOLEAN,
            notify_noparent BOOLEAN,
            created_at DATETIME,
            updated_at DATETIME,
            PRIMARY KEY (id)
        );

        CREATE TABLE IF NOT EXISTS ups_opt_telegram (
            id INTEGER NOT NULL,
            target_id INTEGER,
            display_name VARCHAR(80) NOT NULL,
            bot_token BLOB NOT NULL,
            chat_id BLOB NOT NULL,
            parse_mode VARCHAR(20) NOT NULL,
            disable_web_preview BOOLEAN,
            render_mode VARCHAR(20) NOT NULL,
            is_default BOOLEAN,
            notify_onbatt BOOLEAN,
            notify_online BOOLEAN,
            notify_lowbatt BOOLEAN,
            notify_commok BOOLEAN,
            notify_commbad BOOLEAN,
            notify_shutdown BOOLEAN,
            notify_replbatt BOOLEAN,
            notify_nocomm BOOLEAN,
            notify_noparent BOOLEAN,
            created_at DATETIME,
            updated_at DATETIME,
            PRIMARY KEY (id)
        );

        CREATE TABLE IF NOT EXISTS ups_opt_webhook (
            id INTEGER NOT NULL,
            target_id INTEGER,
            display_name VARCHAR(50) NOT NULL,
            url BLOB NOT NULL,
            server_type VARCHAR(20) NOT NULL,
            request_method VARCHAR(10) NOT NULL,
            content_type VARCHAR(50) NOT NULL,
            auth_type VARCHAR(20) NOT NULL,
            auth_username BLOB,
            auth_password BLOB,
            auth_token BLOB,
            custom_headers TEXT,
            custom_payload TEXT,
            custom_params TEXT,
            render_mode VARCHAR(20) NOT NULL,
            include_ups_data BOOLEAN,
            verify_ssl BOOLEAN,
            is_default BOOLEAN,
            notify_onbatt BOOLEAN,
            notify_online BOOLEAN,
            notify_lowbatt BOOLEAN,
            notify_commok BOOLEAN,
            notify_commbad BOOLEAN,
            notify_shutdown BOOLEAN,
            notify_replbatt BOOLEAN,
            notify_nocomm BOOLEAN,
            notify_noparent BOOLEAN,
            created_at DATETIME,
            updated_at DATETIME,
            PRIMARY KEY (id)
        );

        CREATE TABLE IF NOT EXISTS ups_report_schedules (
            id INTEGER NOT NULL,
            target_id INTEGER,
            time VARCHAR(5) NOT NULL,
            days VARCHAR(20) NOT NULL,
            reports VARCHAR(200) NOT NULL,
            email VARCHAR(255),
            mail_config_id INTEGER,
            period_type VARCHAR(10) NOT NULL,
            from_date DATETIME,
            to_date DATETIME,
            enabled BOOLEAN,
            created_at DATETIME,
            updated_at DATETIME,
            PRIMARY KEY (id)
        );

        CREATE TABLE IF NOT EXISTS ups_variables_upscmd (
            id INTEGER NOT NULL,
            command VARCHAR(100) NOT NULL,
            timestamp DATETIME NOT NULL,
            success BOOLEAN NOT NULL,
            output TEXT,
            target_id INTEGER,
            PRIMARY KEY (id)
        );

        CREATE TABLE IF NOT EXISTS ups_variables_upsrw (
            id INTEGER NOT NULL,
            name VARCHAR(100) NOT NULL,
            old_value VARCHAR(255),
            new_value VARCHAR(255) NOT NULL,
            timestamp_utc DATETIME,
            success BOOLEAN,
            target_id INTEGER,
            PRIMARY KEY (id)
        );
        """
    )


def seed_or_update(conn: sqlite3.Connection) -> None:
    stamp = now()
    ups_name = env("UPS_NAME")
    server_name = env("NUTIFY_SERVER_NAME", "nutify")
    admin_user = env("NUTIFY_ADMIN_USER", "admin")
    admin_password = env("NUTIFY_ADMIN_PASSWORD")

    conn.execute(
        """
        INSERT INTO nutify_master_control
            (id, server_name, monitoring_profile, is_configured, created_at, updated_at)
        VALUES (1, ?, 'single', 1, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            server_name = excluded.server_name,
            monitoring_profile = excluded.monitoring_profile,
            is_configured = 1,
            updated_at = excluded.updated_at
        """,
        (server_name, stamp, stamp),
    )

    existing_user = conn.execute("SELECT id FROM orm_login WHERE username = ?", (admin_user,)).fetchone()
    if existing_user is None:
        conn.execute(
            """
            INSERT INTO orm_login
                (username, password_hash, is_active, is_admin, role, permissions, options_tabs,
                 created_at, updated_at)
            VALUES (?, ?, 1, 1, 'admin', '[]', '[]', ?, ?)
            """,
            (admin_user, generate_password_hash(admin_password), stamp, stamp),
        )
        print(f"[db-init] Created Nutify admin user '{admin_user}'")

    conn.execute(
        """
        INSERT INTO ups_monitor_targets
            (id, name, ups_name, host, port, nut_mode, command_path, source, enabled,
             is_primary, location_enabled, location, location_country, location_region,
             location_city, location_postal_code, location_address, created_at, updated_at)
        VALUES (1, ?, ?, '127.0.0.1', 3493, 'netserver', '/usr/bin/upsc', 'ups-stack',
                1, 1, 0, '', '', '', '', '', '', ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            ups_name = excluded.ups_name,
            host = excluded.host,
            port = excluded.port,
            nut_mode = excluded.nut_mode,
            command_path = excluded.command_path,
            source = excluded.source,
            enabled = 1,
            is_primary = 1,
            updated_at = excluded.updated_at
        """,
        (ups_name, ups_name, stamp, stamp),
    )

    conn.execute(
        """
        INSERT INTO ups_monitor_policies
            (id, target_id, db_strategy, shard_granularity, polling_interval,
             retention_days, notify_scope, created_at, updated_at)
        VALUES (1, 1, 'shared', 'month', 5, 0, 'global', ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            target_id = 1,
            db_strategy = excluded.db_strategy,
            shard_granularity = excluded.shard_granularity,
            polling_interval = excluded.polling_interval,
            retention_days = excluded.retention_days,
            notify_scope = excluded.notify_scope,
            updated_at = excluded.updated_at
        """,
        (stamp, stamp),
    )

    conn.execute(
        """
        INSERT INTO ups_monitor_target_profiles
            (id, target_id, input_sensitivity, device_model, device_serial, device_mfr,
             battery_type, battery_date, battery_mfr_date, created_at, updated_at)
        VALUES (1, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(target_id) DO UPDATE SET
            input_sensitivity = excluded.input_sensitivity,
            device_model = excluded.device_model,
            device_serial = excluded.device_serial,
            device_mfr = excluded.device_mfr,
            battery_type = excluded.battery_type,
            battery_date = excluded.battery_date,
            battery_mfr_date = excluded.battery_mfr_date,
            updated_at = excluded.updated_at
        """,
        (
            os.environ.get("UPS_INPUT_SENSITIVITY", "medium"),
            os.environ.get("UPS_DEVICE_MODEL", os.environ.get("UPS_PRODUCT_STRING", "")),
            os.environ.get("UPS_SERIAL", ""),
            os.environ.get("UPS_VENDOR_NAME", ""),
            os.environ.get("UPS_BATTERY_TYPE", ""),
            os.environ.get("UPS_BATTERY_DATE", ""),
            os.environ.get("UPS_BATTERY_MFR_DATE", ""),
            stamp,
            stamp,
        ),
    )

    conn.execute(
        """
        INSERT INTO ups_opt_variable_config
            (id, target_id, timezone, currency, price_per_kwh, co2_factor, polling_interval,
             measured_power_metric_key, load_metric_key, nominal_power_metric_key,
             realpower_formula, power_calibration_factor, energy_formula, cost_formula,
             co2_formula, created_at, updated_at)
        VALUES (1, 1, ?, 'USD', 0.25, 0.4, 5, 'ups_realpower', 'ups_load',
                'ups_realpower_nominal', '(load_percent / 100.0) * nominal_power_w',
                1.0, 'power_w * delta_hours',
                '(energy_wh / 1000.0) * price_per_kwh',
                '(energy_wh / 1000.0) * co2_factor', ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            target_id = 1,
            timezone = excluded.timezone,
            updated_at = excluded.updated_at
        """,
        (os.environ.get("TZ", "America/Chicago"), stamp, stamp),
    )

    for index, event_type in enumerate(EVENT_TYPES, start=1):
        conn.execute(
            """
            INSERT INTO ups_opt_notification
                (id, target_id, event_type, enabled, ntfy_enabled, telegram_enabled,
                 webhook_enabled, created_at, updated_at)
            VALUES (?, NULL, ?, 0, 0, 0, 0, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                event_type = excluded.event_type,
                updated_at = excluded.updated_at
            """,
            (index, event_type, stamp, stamp),
        )


def main() -> None:
    INSTANCE_DIR.mkdir(parents=True, exist_ok=True)
    os.chmod(INSTANCE_DIR, 0o775)
    ensure_token()

    is_fresh = not DB_PATH.exists()
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys=ON")
    ensure_schema(conn)
    seed_or_update(conn)
    conn.commit()
    conn.close()

    if is_fresh:
        print(f"[db-init] Created {DB_PATH}")
    else:
        print(f"[db-init] Updated {DB_PATH}")


if __name__ == "__main__":
    main()

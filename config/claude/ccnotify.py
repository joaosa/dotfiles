#!/usr/bin/env python3
"""
Claude Code Notify
https://github.com/dazuiba/CCNotify
"""

import json
import logging
import os
import shlex
import sqlite3
import subprocess
import sys
from datetime import datetime
from logging.handlers import TimedRotatingFileHandler

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


class ClaudePromptTracker:
    def __init__(self):
        """Initialize the prompt tracker with database setup"""
        self.db_path = os.path.join(SCRIPT_DIR, "ccnotify.db")
        self.setup_logging()
        self.init_database()

    def setup_logging(self):
        """Setup logging to file with daily rotation"""
        handler = TimedRotatingFileHandler(
            os.path.join(SCRIPT_DIR, "ccnotify.log"),
            when="midnight",  # Rotate at midnight
            interval=1,  # Every 1 day
            backupCount=1,  # Keep 1 day of logs
            encoding="utf-8",
        )

        formatter = logging.Formatter(
            "%(asctime)s - %(levelname)s - %(message)s", datefmt="%Y-%m-%d %H:%M:%S"
        )
        handler.setFormatter(formatter)

        logger = logging.getLogger()
        logger.setLevel(logging.INFO)
        logger.addHandler(handler)

    def init_database(self):
        """Create tables and triggers if they don't exist"""
        with sqlite3.connect(self.db_path) as conn:
            # Create main table
            conn.execute("""
                CREATE TABLE IF NOT EXISTS prompt (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT NOT NULL,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    prompt TEXT,
                    cwd TEXT,
                    seq INTEGER,
                    stoped_at DATETIME,
                    lastWaitUserAt DATETIME
                )
            """)

            # Create trigger for auto-incrementing seq
            conn.execute("""
                CREATE TRIGGER IF NOT EXISTS auto_increment_seq
                AFTER INSERT ON prompt
                FOR EACH ROW
                BEGIN
                    UPDATE prompt
                    SET seq = (
                        SELECT COALESCE(MAX(seq), 0) + 1
                        FROM prompt
                        WHERE session_id = NEW.session_id
                    )
                    WHERE id = NEW.id;
                END
            """)

            conn.commit()

    def handle_user_prompt_submit(self, data):
        """Handle UserPromptSubmit event - insert new prompt record"""
        session_id = data.get("session_id")
        prompt = data.get("prompt", "")
        cwd = data.get("cwd", "")

        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                INSERT INTO prompt (session_id, prompt, cwd)
                VALUES (?, ?, ?)
            """,
                (session_id, prompt, cwd),
            )
            conn.commit()

        logging.info("Recorded prompt for session %s", session_id)

    def handle_stop(self, data):
        """Handle Stop event - update completion time and send notification"""
        session_id = data.get("session_id")

        with sqlite3.connect(self.db_path) as conn:
            # Find the latest unfinished record for this session
            cursor = conn.execute(
                """
                SELECT id, cwd
                FROM prompt
                WHERE session_id = ? AND stoped_at IS NULL
                ORDER BY created_at DESC
                LIMIT 1
            """,
                (session_id,),
            )

            row = cursor.fetchone()
            if row:
                record_id, cwd = row

                # Update completion time
                conn.execute(
                    """
                    UPDATE prompt
                    SET stoped_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                """,
                    (record_id,),
                )
                conn.commit()

                # Get seq number and calculate duration
                cursor = conn.execute(
                    "SELECT seq FROM prompt WHERE id = ?", (record_id,)
                )
                seq_row = cursor.fetchone()
                seq = seq_row[0] if seq_row else 1

                duration = self.calculate_duration_from_db(record_id)
                self.send_notification(
                    title=os.path.basename(cwd) if cwd else "Claude Task",
                    subtitle=f"job#{seq} done, duration: {duration}",
                    cwd=cwd,
                )

                logging.info(
                    "Task completed for session %s, job#%s, duration: %s",
                    session_id,
                    seq,
                    duration,
                )

    def handle_notification(self, data):
        """Handle Notification event - check for various notification types and send notifications"""
        session_id = data.get("session_id")
        message = data.get("message", "")
        cwd = data.get("cwd", "")

        # Log all notifications for debugging
        logging.info("[NOTIFICATION] session=%s, message=%r", session_id, message)

        # Determine notification type and subtitle
        message_lower = message.lower()
        subtitle = None
        should_update_db = False
        should_notify = True

        if (
            "waiting for your input" in message_lower
            or "waiting for input" in message_lower
        ):
            subtitle = "Waiting for input"
            should_update_db = True
            # The Stop handler sends "job done" instead.
            should_notify = False
        elif "permission" in message_lower:
            subtitle = "Permission Required"
        elif "approval" in message_lower or "choose an option" in message_lower:
            subtitle = "Action Required"
        else:
            # For other notifications, use a generic subtitle
            subtitle = "Notification"

        # Update database for waiting notifications
        if should_update_db:
            with sqlite3.connect(self.db_path) as conn:
                # Subquery, since SQLite's UPDATE lacks ORDER BY/LIMIT by default
                conn.execute(
                    """
                    UPDATE prompt
                    SET lastWaitUserAt = CURRENT_TIMESTAMP
                    WHERE id = (
                        SELECT id FROM prompt
                        WHERE session_id = ?
                        ORDER BY created_at DESC
                        LIMIT 1
                    )
                """,
                    (session_id,),
                )
                conn.commit()
            logging.info("Updated lastWaitUserAt for session %s", session_id)

        # Send notification only if should_notify is True
        if should_notify:
            self.send_notification(
                title=os.path.basename(cwd) if cwd else "Claude Task",
                subtitle=subtitle,
                cwd=cwd,
            )
            logging.info("Notification sent for session %s: %s", session_id, subtitle)
        else:
            logging.info(
                "Notification suppressed for session %s: %s", session_id, subtitle
            )

    def calculate_duration_from_db(self, record_id):
        """Calculate duration for a completed record"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute(
                """
                SELECT created_at, stoped_at
                FROM prompt
                WHERE id = ?
            """,
                (record_id,),
            )

            row = cursor.fetchone()
            if row and row[1]:
                return self.calculate_duration(row[0], row[1])

        return "Unknown"

    def calculate_duration(self, start_time, end_time):
        """Calculate human-readable duration between two timestamps"""
        try:
            start_dt = datetime.fromisoformat(start_time)
            end_dt = datetime.fromisoformat(end_time)
        except (TypeError, ValueError):
            logging.exception("Error calculating duration")
            return "Unknown"

        total_seconds = int((end_dt - start_dt).total_seconds())
        if total_seconds < 60:
            return f"{total_seconds}s"
        if total_seconds < 3600:
            minutes, seconds = divmod(total_seconds, 60)
            return f"{minutes}m{seconds}s" if seconds else f"{minutes}m"
        hours, minutes = divmod(total_seconds // 60, 60)
        return f"{hours}h{minutes}m" if minutes else f"{hours}h"

    def send_notification(self, title, subtitle, cwd=None):
        """Send macOS notification using terminal-notifier"""
        current_time = datetime.now().strftime("%B %d, %Y at %H:%M")

        try:
            cmd = [
                "terminal-notifier",
                "-sound",
                "default",
                "-title",
                title,
                "-subtitle",
                f"{subtitle}\n{current_time}",
            ]

            if cwd:
                # Deviation from upstream: -execute is a shell string, so a
                # crafted cwd must not inject into the click action.
                cmd.extend(["-execute", f"/usr/local/bin/code {shlex.quote(cwd)}"])

            subprocess.run(cmd, check=False, capture_output=True)
            logging.info("Notification sent: %s - %s", title, subtitle)
        except FileNotFoundError:
            logging.warning("terminal-notifier not found, notification skipped")
        except OSError:
            logging.exception("Error sending notification")


def validate_input_data(data, expected_event_name):
    """Validate input data matches design specification"""
    required_fields = {
        "UserPromptSubmit": ["session_id", "prompt", "cwd", "hook_event_name"],
        "Stop": ["session_id", "hook_event_name"],
        "Notification": ["session_id", "message", "hook_event_name"],
    }

    if expected_event_name not in required_fields:
        raise ValueError(f"Unknown event type: {expected_event_name}")

    # Check hook_event_name matches expected
    if data.get("hook_event_name") != expected_event_name:
        raise ValueError(
            f"Event name mismatch: expected {expected_event_name}, got {data.get('hook_event_name')}"
        )

    missing_fields = [
        field
        for field in required_fields[expected_event_name]
        if data.get(field) is None
    ]

    if missing_fields:
        raise ValueError(
            f"Missing required fields for {expected_event_name}: {missing_fields}"
        )


def main():
    """Main entry point - read JSON from stdin and process event"""
    try:
        # Check if hook type is provided as command line argument
        if len(sys.argv) < 2:
            print("ok")
            return

        expected_event_name = sys.argv[1]
        handlers = {
            "UserPromptSubmit": ClaudePromptTracker.handle_user_prompt_submit,
            "Stop": ClaudePromptTracker.handle_stop,
            "Notification": ClaudePromptTracker.handle_notification,
        }

        if expected_event_name not in handlers:
            logging.error("Invalid hook type: %s", expected_event_name)
            logging.error("Valid hook types: %s", ", ".join(handlers))
            sys.exit(1)

        # Read JSON data from stdin
        input_data = sys.stdin.read().strip()
        if not input_data:
            logging.warning("No input data received")
            return

        data = json.loads(input_data)

        validate_input_data(data, expected_event_name)
        handlers[expected_event_name](ClaudePromptTracker(), data)

    except json.JSONDecodeError as e:
        logging.error("JSON decode error: %s", e)
        sys.exit(1)
    except ValueError as e:
        logging.error("Validation error: %s", e)
        sys.exit(1)
    except Exception:
        logging.exception("Unexpected error")
        sys.exit(1)


if __name__ == "__main__":
    main()

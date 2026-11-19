#!/usr/bin/env python3
"""Telegram bot for FI VPN server status, reboot, and torrent blocker (@Vpn_Sharpmaind_bot)."""

from __future__ import annotations

import asyncio
import html
import io
import json
import logging
import os
import re
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from telegram import BotCommand, InlineKeyboardButton, InlineKeyboardMarkup, InputFile, MenuButtonCommands, Update
from telegram.ext import Application, CallbackQueryHandler, CommandHandler, ContextTypes, MessageHandler, filters

logging.basicConfig(
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    level=logging.INFO,
)
log = logging.getLogger("vpn-bot")

BOT_TOKEN = os.environ.get("BOT_TOKEN", "").strip()
ALLOWED_CHAT_IDS = {
    int(x.strip())
    for x in os.environ.get("ALLOWED_CHAT_IDS", "").split(",")
    if x.strip().isdigit()
}

FI_IP = "89.125.57.161"

REMNAWAVE_BASE_URL = os.environ.get(
    "REMNAWAVE_BASE_URL", "https://vpn2.sharpmaind.ru"
).rstrip("/")
REMNAWAVE_API_TOKEN = os.environ.get("REMNAWAVE_API_TOKEN", "").strip()
REMNAWAVE_PLUGIN_UUID = os.environ.get("REMNAWAVE_PLUGIN_UUID", "").strip()
REMNAWAVE_NODE_UUID = os.environ.get("REMNAWAVE_NODE_UUID", "").strip()
REMNAWAVE_PROFILE_UUID = os.environ.get("REMNAWAVE_PROFILE_UUID", "").strip()
REMNAWAVE_BLOCK_DURATION = int(os.environ.get("REMNAWAVE_BLOCK_DURATION", "3600"))

AWG_PANEL_URL = os.environ.get("AWG_PANEL_URL", "http://127.0.0.1:5000").rstrip("/")
AWG_PANEL_USER = os.environ.get("AWG_PANEL_USER", "admin").strip()
AWG_PANEL_PASSWORD = os.environ.get("AWG_PANEL_PASSWORD", "").strip()
AWG_AUTO_CREATE_USERS = os.environ.get("AWG_AUTO_CREATE_USERS", "1").strip().lower() in {
    "1", "true", "yes", "on"
}
AWG_PANEL_PUBLIC_URL = os.environ.get("AWG_PANEL_PUBLIC_URL", "https://awg.sharpmaind.ru").rstrip("/")

BT_BLOCK_RULE = {
    "protocol": ["bittorrent"],
    "outboundTag": "TORRENT_CUT",
    "ruleTag": "TORRENT_CUT",
}
TORRENT_CUT_OUTBOUND = {"tag": "TORRENT_CUT", "protocol": "blackhole"}
TORRENT_ALERT_POLL_SEC = int(os.environ.get("TORRENT_ALERT_POLL_SEC", "15"))
TORRENT_ALERT_COOLDOWN_SEC = int(os.environ.get("TORRENT_ALERT_COOLDOWN_SEC", "300"))
TORRENT_ALERT_STATE_FILE = os.environ.get(
    "TORRENT_ALERT_STATE_FILE", "/app/data/torrent_alerts_state.json"
)
TORRENT_ACCESS_LOG = os.environ.get(
    "TORRENT_ACCESS_LOG", "/var/log/remnanode/access.log"
)

HELP_TEXT = """SharpVpnBot — Ops

Выберите действие кнопками ниже.
AWG панель → сразу список клиентов AmneziaWG.

Команды дублируют кнопки: /status /torrent /reboot /myid"""


def icon(ok: bool) -> str:
    return "✅" if ok else "❌"


def esc(text: str) -> str:
    return html.escape(text, quote=False)


def run_local(cmd: list[str], timeout: int = 30) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        out = (proc.stdout or "") + (proc.stderr or "")
        return proc.returncode, out.strip()
    except subprocess.TimeoutExpired:
        return 124, "timeout"
    except Exception as exc:
        return 1, str(exc)



class AwgPanelError(Exception):
    pass


def awg_configured() -> bool:
    return bool(AWG_PANEL_URL and AWG_PANEL_USER and AWG_PANEL_PASSWORD)


class _AwgSession:
    def __init__(self) -> None:
        self._opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor())

    def request(self, method: str, path: str, payload: dict | None = None):
        url = f"{AWG_PANEL_URL}{path}"
        data = None
        headers = {"Accept": "application/json"}
        if payload is not None:
            data = json.dumps(payload).encode()
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with self._opener.open(req, timeout=20) as resp:
                raw = resp.read().decode() or "{}"
                try:
                    return resp.status, json.loads(raw)
                except json.JSONDecodeError:
                    return resp.status, raw
        except urllib.error.HTTPError as exc:
            raw = exc.read().decode() if exc.fp else ""
            try:
                body = json.loads(raw) if raw else {"error": str(exc)}
            except json.JSONDecodeError:
                body = raw or str(exc)
            return exc.code, body

    def login(self) -> None:
        code, body = self.request(
            "POST",
            "/api/auth/login",
            {"username": AWG_PANEL_USER, "password": AWG_PANEL_PASSWORD},
        )
        if code >= 400:
            raise AwgPanelError(f"AWG login failed HTTP {code}: {body}")


def awg_find_user_by_telegram(session: _AwgSession, tg_id: str) -> dict | None:
    code, body = session.request("GET", "/api/users?size=200")
    if code >= 400:
        raise AwgPanelError(f"users list failed HTTP {code}: {body}")
    users = body.get("users") if isinstance(body, dict) else body
    if not isinstance(users, list):
        raise AwgPanelError(f"unexpected users payload: {body}")
    for user in users:
        if str(user.get("telegramId") or "").strip() == str(tg_id):
            return user
    return None


def awg_ensure_user(tg_id: str, username_hint: str, display_name: str) -> tuple[dict, str | None]:
    session = _AwgSession()
    session.login()
    existing = awg_find_user_by_telegram(session, tg_id)
    if existing:
        return existing, None
    base = (username_hint or display_name or f"tg_{tg_id}").strip()[:60] or f"tg_{tg_id}"
    password = secrets.token_urlsafe(12)
    payload = {
        "username": base,
        "password": password,
        "role": "user",
        "telegramId": str(tg_id),
        "description": f"Created from SharpVpnBot /start ({display_name})",
    }
    code, body = session.request("POST", "/api/users/add", payload)
    if code >= 400:
        payload["username"] = f"{base[:40]}_{str(tg_id)[-4:]}"
        code, body = session.request("POST", "/api/users/add", payload)
    if code >= 400:
        raise AwgPanelError(f"create user failed HTTP {code}: {body}")
    created = awg_find_user_by_telegram(session, tg_id) or (body if isinstance(body, dict) else {})
    return created, password


def is_allowed(update: Update) -> bool:
    if not ALLOWED_CHAT_IDS:
        return False
    chat_id = update.effective_chat.id if update.effective_chat else None
    user_id = update.effective_user.id if update.effective_user else None
    return chat_id in ALLOWED_CHAT_IDS or user_id in ALLOWED_CHAT_IDS


async def deny(update: Update) -> None:
    chat_id = update.effective_chat.id if update.effective_chat else "?"
    text = (
        f"Доступ запрещён.\n"
        f"Ваш chat_id: <code>{esc(str(chat_id))}</code>\n\n"
        "Добавьте его в ALLOWED_CHAT_IDS на сервере и перезапустите бота."
    )
    if update.message:
        await update.message.reply_text(text, parse_mode="HTML")
    elif update.callback_query:
        await update.callback_query.answer("Доступ запрещён", show_alert=True)


def format_uptime(raw: str) -> str:
    raw = raw.strip()
    m = re.search(r"up\s+(.+?),\s*\d+\s+user", raw)
    if m:
        return m.group(1).strip()
    m = re.search(r"up\s+(.+)", raw)
    return m.group(1).split(",")[0].strip() if m else raw


def format_disk(raw: str) -> str:
    parts = raw.split()
    if len(parts) >= 5:
        used_pct = parts[4].rstrip("%")
        free = parts[3]
        return f"{used_pct}% занято, {free} свободно"
    return raw


def format_mem(raw: str) -> str:
    parts = raw.split()
    if len(parts) >= 7:
        return f"{parts[2]} занято / {parts[6]} доступно"
    return raw


def collect_host_metrics(getter) -> tuple[str, str, str] | None:
    uptime_raw = getter(["uptime"])
    disk_raw = getter(["sh", "-c", "df -h / | tail -1"])
    mem_raw = getter(["sh", "-c", "free -h | awk 'NR==2'"])
    if not any((uptime_raw, disk_raw, mem_raw)):
        return None
    return (
        format_uptime(uptime_raw),
        format_disk(disk_raw),
        format_mem(mem_raw),
    )


def host_metrics_local() -> tuple[str, str, str] | str:
    def getter(cmd: list[str]) -> str:
        _, out = run_local(cmd)
        return out

    data = collect_host_metrics(getter)
    if data is None:
        return "нет данных"
    return data


def check_local(name: str, url: str, ok_codes: set[int] | None = None) -> tuple[str, bool]:
    if ok_codes is None:
        code, _ = run_local(["curl", "-sf", url, "-o", "/dev/null"])
        return name, code == 0
    _code, out = run_local(["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", url])
    try:
        status = int((out or "").strip() or "0")
    except ValueError:
        status = 0
    return name, status in ok_codes


def health_checks_local() -> list[tuple[str, bool]]:
    return [
        check_local("Remnawave", "http://127.0.0.1:3001/health"),
        check_local("Uptime Kuma", "http://127.0.0.1:3002/dashboard"),
        check_local("AWG Panel", "http://127.0.0.1:5000/"),
        check_local("vpn2.sharpmaind.ru", "https://vpn2.sharpmaind.ru/", ok_codes={200, 401}),
        check_local("awg.sharpmaind.ru", "https://awg.sharpmaind.ru/"),
    ]


def awg_dacha_handshake() -> tuple[str, bool]:
    code, out = run_local(
        [
            "docker",
            "exec",
            "amnezia-awg2",
            "awg",
            "show",
            "awg0",
            "dump",
        ]
    )
    if code != 0:
        return "AWG дача (10.8.1.8)", False
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) >= 4 and parts[3] == "10.8.1.8/32":
            hs = int(parts[4] or "0")
            age = "нет handshake" if hs == 0 else f"handshake {hs}"
            return f"AWG дача (10.8.1.8, {age})", hs > 0
    return "AWG дача (10.8.1.8)", False


def docker_lines_local() -> list[tuple[str, bool, str]]:
    code, out = run_local(
        ["docker", "ps", "--format", "{{.Names}}|{{.Status}}"]
    )
    if code != 0:
        return [("docker", False, out or "error")]
    lines: list[tuple[str, bool, str]] = []
    for row in out.splitlines():
        if "|" not in row:
            continue
        name, status = row.split("|", 1)
        lines.append((name.strip(), "Up" in status, status.strip()))
    return lines or [("docker", False, "нет контейнеров")]


def format_metrics_block(metrics: tuple[str, str, str] | str) -> str:
    if isinstance(metrics, str):
        return esc(metrics)
    uptime, disk, mem = metrics
    return (
        f"⏱ Uptime: {esc(uptime)}\n"
        f"📀 Диск: {esc(disk)}\n"
        f"🧠 RAM: {esc(mem)}"
    )


def format_checks_block(checks: list[tuple[str, bool]] | str) -> str:
    if isinstance(checks, str):
        return esc(checks)
    return "\n".join(f"{icon(ok)} {esc(name)}" for name, ok in checks)


def format_docker_block(lines: list[tuple[str, bool, str]] | str) -> str:
    if isinstance(lines, str):
        return esc(lines)
    return "\n".join(
        f"{icon(up)} <code>{esc(name)}</code> — {esc(status)}"
        for name, up, status in lines
    )


def build_status_text() -> str:
    checks = health_checks_local()
    checks.append(awg_dacha_handshake())
    torrent_line = "\n\n<b>P2P / torrent</b>\n⚠️ статус среза недоступен — /torrent"
    try:
        cut_on = get_torrent_cut_enabled()
        torrent_line = (
            "\n\n<b>P2P / torrent</b>\n"
            f"{'🟢 срез ВКЛ' if cut_on else '🔴 срез ВЫКЛ'} — /torrent"
        )
    except Exception as exc:
        torrent_line = (
            "\n\n<b>P2P / torrent</b>\n"
            f"⚠️ {esc(str(exc)[:120])} — /torrent"
        )
    return (
        "<b>📡 SharpVPN — FI сервер</b>\n\n"
        f"🇫🇮 <b>Финляндия</b> <code>{esc(FI_IP)}</code>\n"
        f"{format_metrics_block(host_metrics_local())}\n\n"
        f"<b>Сервисы</b>\n"
        f"{format_checks_block(checks)}"
        f"{torrent_line}\n\n"
        f"<b>Docker</b>\n"
        f"{format_docker_block(docker_lines_local())}"
    )


def reboot_local() -> None:
    subprocess.Popen(["/usr/sbin/reboot"], start_new_session=True)





AWG_DATA_FILE = Path(os.environ.get("AWG_DATA_FILE", "/app/awg-data.json"))


def load_awg_data() -> dict:
    if AWG_DATA_FILE.exists():
        return json.loads(AWG_DATA_FILE.read_text())
    code, out = run_local(["docker", "exec", "amnezia_panel", "cat", "/app/data/data.json"])
    if code != 0:
        raise RuntimeError(out or "cannot read AWG data.json")
    return json.loads(out)



def awg_default_target(data: dict | None = None) -> tuple[int, str]:
    """Pick first server + preferred AWG protocol for one-tap panel entry."""
    data = data or load_awg_data()
    servers = data.get("servers") or []
    if not servers:
        raise RuntimeError("В панели нет серверов")
    sid = 0
    protocols = (servers[sid].get("protocols") or {}) if isinstance(servers[sid], dict) else {}
    keys = list(protocols.keys())
    for pref in ("awg3", "awg2", "awg"):
        if pref in keys:
            return sid, pref
    for key in keys:
        if str(key).startswith("awg"):
            return sid, str(key)
    if keys:
        return sid, str(keys[0])
    raise RuntimeError("На сервере нет протоколов")


async def open_awg_clients_home(query_or_msg, context: ContextTypes.DEFAULT_TYPE, *, edit: bool) -> None:
    sid, proto = await asyncio.to_thread(lambda: awg_default_target())
    server = await asyncio.to_thread(awg_refresh_server, sid)
    info = (server.get("protocols") or {}).get(proto) or {}
    clients = await asyncio.to_thread(awg_list_clients, sid, proto)
    context.user_data[f"awg_clients:{sid}:{proto}"] = clients
    label = esc(str(info.get("display_name") or proto))
    status = "🟢 running" if info.get("container_running") is True else (
        "🔴 stopped" if info.get("container_running") is False else "⚪ unknown"
    )
    lines = [
        f"🛡 <b>AWG панель</b>",
        f"🔌 <b>{label}</b> (<code>{esc(proto)}</code>)",
        f"Сервер: <b>{esc(str(server.get('name') or server.get('host')))}</b>",
        f"Статус: <b>{status}</b>",
    ]
    for key, title in (("container_name", "Container"), ("port", "Port")):
        if info.get(key) not in (None, ""):
            lines.append(f"{title}: <code>{esc(str(info.get(key)))}</code>")
    lines.append("")
    lines.append(f"👥 Клиенты: <b>{len(clients)}</b>")
    text_out = "\n".join(lines)
    markup = awg_clients_keyboard(sid, proto, clients)
    if edit:
        await _edit_or_answer(query_or_msg, text_out, markup)
    else:
        await query_or_msg.reply_text(text_out, parse_mode="HTML", reply_markup=markup)

def ops_keyboard() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton("📊 Status", callback_data="ops:status"),
                InlineKeyboardButton("🚫 P2P / torrent", callback_data="ops:torrent"),
            ],
            [InlineKeyboardButton("🔄 Reboot FI", callback_data="ops:reboot")],
            [InlineKeyboardButton("🛡 AWG панель", callback_data="awg:menu")],
            [InlineKeyboardButton("🆔 myid", callback_data="ops:myid")],
        ]
    )


def awg_main_keyboard() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        [
            [InlineKeyboardButton("🖥 Серверы", callback_data="awg:servers")],
            [InlineKeyboardButton("👤 Пользователи", callback_data="awg:users")],
            [InlineKeyboardButton("⬅️ Ops", callback_data="ops:menu")],
        ]
    )


def awg_servers_keyboard(data: dict) -> InlineKeyboardMarkup:
    rows = []
    for sid, srv in enumerate(data.get("servers") or []):
        name = srv.get("name") or srv.get("host") or f"Сервер {sid+1}"
        rows.append([InlineKeyboardButton(f"🖥 {name}", callback_data=f"awg:srv:{sid}")])
    if not rows:
        rows.append([InlineKeyboardButton("Нет серверов", callback_data="ops:noop")])
    rows.append([InlineKeyboardButton("⬅️ AWG меню", callback_data="awg:menu")])
    return InlineKeyboardMarkup(rows)


def _proto_icon(info: dict) -> str:
    if info.get("status_error"):
        return "⚪"
    running = info.get("container_running")
    if running is True:
        return "🟢"
    if running is False:
        return "🔴"
    return "⚪"


def awg_protocols_keyboard(server_id: int, server: dict) -> InlineKeyboardMarkup:
    rows = []
    for proto, info in (server.get("protocols") or {}).items():
        info = info or {}
        label = info.get("display_name") or proto
        mark = "✅" if info.get("installed", True) else ""
        rows.append(
            [
                InlineKeyboardButton(
                    f"{mark}{_proto_icon(info)} {label}",
                    callback_data=f"awg:proto:{server_id}:{proto}",
                )
            ]
        )
    if not rows:
        rows.append([InlineKeyboardButton("Нет протоколов", callback_data="ops:noop")])
    rows.append([InlineKeyboardButton("⬅️ Серверы", callback_data="awg:servers")])
    return InlineKeyboardMarkup(rows)


def awg_protocol_keyboard(server_id: int, proto: str) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        [
            [InlineKeyboardButton("👥 Клиенты", callback_data=f"awg:clients:{server_id}:{proto}")],
            [InlineKeyboardButton("➕ Новый клиент", callback_data=f"awg:addclient:{server_id}:{proto}")],
            [InlineKeyboardButton("🔄 Обновить", callback_data=f"awg:proto:{server_id}:{proto}")],
            [InlineKeyboardButton("⬅️ Сервер", callback_data=f"awg:srv:{server_id}")],
        ]
    )


def awg_clients_keyboard(server_id: int, proto: str, clients: list | None = None) -> InlineKeyboardMarkup:
    rows = [
        [InlineKeyboardButton("➕ Новый клиент", callback_data=f"awg:addclient:{server_id}:{proto}")],
    ]
    for idx, client in enumerate(clients or []):
        if not isinstance(client, dict):
            label = str(client)
        else:
            label = str(client.get("name") or client.get("id") or f"#{idx+1}")
        if len(label) > 40:
            label = label[:37] + "..."
        rows.append(
            [InlineKeyboardButton(f"👤 {label}", callback_data=f"awg:cli:{server_id}:{proto}:{idx}")]
        )
    rows.append([InlineKeyboardButton("🔄 Обновить", callback_data=f"awg:clients:{server_id}:{proto}")])
    rows.append([InlineKeyboardButton("⬅️ Ops", callback_data="ops:menu")])
    return InlineKeyboardMarkup(rows)


def awg_client_menu_keyboard(server_id: int, proto: str, idx: int) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        [
            [InlineKeyboardButton("📄 Получить конфиг", callback_data=f"awg:cfg:{server_id}:{proto}:{idx}")],
            [InlineKeyboardButton("🗑 Удалить", callback_data=f"awg:del:{server_id}:{proto}:{idx}")],
            [InlineKeyboardButton("⬅️ Клиенты", callback_data=f"awg:clients:{server_id}:{proto}")],
        ]
    )


def awg_client_delete_confirm_keyboard(server_id: int, proto: str, idx: int) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton("✅ Да, удалить", callback_data=f"awg:delok:{server_id}:{proto}:{idx}"),
                InlineKeyboardButton("❌ Нет", callback_data=f"awg:cli:{server_id}:{proto}:{idx}"),
            ]
        ]
    )


def awg_refresh_server(server_id: int) -> dict:
    session = _AwgSession()
    session.login()
    code, body = session.request("POST", f"/api/servers/{server_id}/check")
    data = load_awg_data()
    servers = data.get("servers") or []
    if server_id < 0 or server_id >= len(servers):
        raise RuntimeError("server not found")
    server = dict(servers[server_id])
    # merge live protocol statuses when API returned them
    if isinstance(body, dict):
        live = (body.get("protocols") or {}) if "protocols" in body else body
        if isinstance(live, dict) and live:
            protocols = dict(server.get("protocols") or {})
            # API may use base names awg/awg2; keep installed keys and update matching
            for key, info in list(protocols.items()):
                base = re.sub(r"\d+$", "", key)
                src = live.get(key) or live.get(base) or {}
                if isinstance(src, dict) and src:
                    merged = dict(info or {})
                    merged.update({k: src.get(k) for k in ("container_running", "container_exists", "status_error", "display_name", "container_name", "port") if k in src})
                    protocols[key] = merged
            server["protocols"] = protocols
            if body.get("connection"):
                server["_connection"] = body.get("connection")
    return server


def awg_list_clients(server_id: int, proto: str) -> list:
    session = _AwgSession()
    session.login()
    code, body = session.request("GET", f"/api/servers/{server_id}/{proto}/clients")
    if code >= 400:
        # try base protocol name
        base = re.sub(r"\d+$", "", proto)
        code, body = session.request("GET", f"/api/servers/{server_id}/{base}/clients")
    if code >= 400:
        raise RuntimeError(f"clients HTTP {code}: {body}")
    if isinstance(body, dict):
        return body.get("clients") or []
    return body if isinstance(body, list) else []



def awg_add_client(server_id: int, proto: str, name: str) -> dict:
    name = (name or "").strip()
    if not name:
        raise RuntimeError("пустое имя клиента")
    session = _AwgSession()
    session.login()
    code, body = session.request(
        "POST",
        f"/api/servers/{server_id}/connections/add",
        {"protocol": proto, "name": name},
    )
    if code >= 400:
        base = re.sub(r"\d+$", "", proto)
        if base != proto:
            code, body = session.request(
                "POST",
                f"/api/servers/{server_id}/connections/add",
                {"protocol": base, "name": name},
            )
    if code >= 400:
        raise RuntimeError(f"add client HTTP {code}: {body}")
    if not isinstance(body, dict):
        raise RuntimeError(f"unexpected add client response: {body}")
    return body

def awg_remove_client(server_id: int, proto: str, client_id: str) -> dict:
    session = _AwgSession()
    session.login()
    code, body = session.request(
        "POST",
        f"/api/servers/{server_id}/connections/remove",
        {"protocol": proto, "client_id": client_id},
    )
    if code >= 400:
        base = re.sub(r"\d+$", "", proto)
        if base != proto:
            code, body = session.request(
                "POST",
                f"/api/servers/{server_id}/connections/remove",
                {"protocol": base, "client_id": client_id},
            )
    if code >= 400:
        raise RuntimeError(f"remove client HTTP {code}: {body}")
    return body if isinstance(body, dict) else {"status": "ok", "raw": body}


def awg_get_client_config(server_id: int, proto: str, client_id: str) -> dict:
    session = _AwgSession()
    session.login()
    code, body = session.request(
        "POST",
        f"/api/servers/{server_id}/connections/config",
        {"protocol": proto, "client_id": client_id},
    )
    if code >= 400:
        base = re.sub(r"\d+$", "", proto)
        if base != proto:
            code, body = session.request(
                "POST",
                f"/api/servers/{server_id}/connections/config",
                {"protocol": base, "client_id": client_id},
            )
    if code >= 400:
        raise RuntimeError(f"get config HTTP {code}: {body}")
    if not isinstance(body, dict):
        raise RuntimeError(f"unexpected config response: {body}")
    return body


def awg_list_users_brief() -> tuple[int, list]:
    session = _AwgSession()
    session.login()
    code, body = session.request("GET", "/api/users?size=50")
    if code >= 400:
        raise RuntimeError(f"users HTTP {code}: {body}")
    users = body.get("users") if isinstance(body, dict) else []
    total = body.get("total") if isinstance(body, dict) else len(users or [])
    return int(total or 0), users or []


def confirm_keyboard() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton(
                    "✅ Да, перезагрузить",
                    callback_data="reboot:fi:yes",
                ),
                InlineKeyboardButton("❌ Отмена", callback_data="reboot:cancel"),
            ]
        ]
    )


def remnawave_configured() -> bool:
    return bool(REMNAWAVE_API_TOKEN and REMNAWAVE_NODE_UUID)


def remnawave_request(
    method: str, path: str, body: dict | None = None, timeout: int = 60
) -> dict:
    if not remnawave_configured():
        raise RuntimeError("Remnawave API не настроен (нет token/node)")
    url = f"{REMNAWAVE_BASE_URL}{path}"
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {REMNAWAVE_API_TOKEN}",
            "Accept": "application/json",
            "Content-Type": "application/json",
            "User-Agent": "vpn-bot/torrent-cut-toggle",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:300]
        raise RuntimeError(f"HTTP {exc.code}: {detail}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"сеть: {exc.reason}") from exc


def get_active_profile_uuid() -> str:
    if REMNAWAVE_PROFILE_UUID:
        return REMNAWAVE_PROFILE_UUID
    payload = remnawave_request("GET", "/api/nodes/")
    nodes = payload.get("response")
    if isinstance(nodes, dict):
        nodes = nodes.get("nodes") or []
    if not isinstance(nodes, list):
        raise RuntimeError("не удалось получить список нод")
    node = next((n for n in nodes if n.get("uuid") == REMNAWAVE_NODE_UUID), None)
    if not node:
        raise RuntimeError("нода не найдена")
    profile = (node.get("configProfile") or {}).get("activeConfigProfileUuid")
    if not profile:
        raise RuntimeError("у ноды нет active config profile")
    return profile


def _is_bt_block_rule(rule: dict) -> bool:
    protos = rule.get("protocol") or []
    if "bittorrent" not in protos:
        return False
    return rule.get("outboundTag") in {"TORRENT_CUT", "BLOCK"}


def get_profile_config(profile_uuid: str) -> dict:
    payload = remnawave_request("GET", f"/api/config-profiles/{profile_uuid}")
    config = (payload.get("response") or {}).get("config")
    if isinstance(config, str):
        config = json.loads(config)
    if not isinstance(config, dict):
        raise RuntimeError("config профиля пустой")
    return config


def get_torrent_cut_enabled() -> bool:
    profile_uuid = get_active_profile_uuid()
    config = get_profile_config(profile_uuid)
    rules = ((config.get("routing") or {}).get("rules")) or []
    return any(_is_bt_block_rule(r) for r in rules if isinstance(r, dict))


def set_torrent_cut_enabled(enabled: bool) -> bool:
    """Toggle Xray routing rule bittorrent→TORRENT_CUT. Never enables IP-ban plugin."""
    profile_uuid = get_active_profile_uuid()
    config = get_profile_config(profile_uuid)

    # Keep/ensure dedicated blackhole + access log for alerts (no IP ban).
    config["log"] = {
        "access": "/var/log/remnanode/access.log",
        "error": "/var/log/remnanode/error.log",
        "loglevel": (config.get("log") or {}).get("loglevel") or "warning",
    }
    outbounds = list(config.get("outbounds") or [])
    if not any(o.get("tag") == "TORRENT_CUT" for o in outbounds if isinstance(o, dict)):
        outbounds.append(dict(TORRENT_CUT_OUTBOUND))
    config["outbounds"] = outbounds

    routing = dict(config.get("routing") or {})
    rules = [r for r in (routing.get("rules") or []) if not _is_bt_block_rule(r)]
    if enabled:
        rules.append(dict(BT_BLOCK_RULE))
    routing["rules"] = rules
    config["routing"] = routing

    remnawave_request(
        "PATCH",
        "/api/config-profiles/",
        {"uuid": profile_uuid, "config": config},
    )
    remnawave_request(
        "POST",
        f"/api/nodes/{REMNAWAVE_NODE_UUID}/actions/restart",
        {"forceRestart": False},
    )
    try:
        ensure_ip_ban_plugin_off()
    except Exception as exc:
        log.warning("IP-ban plugin ensure-off failed: %s", exc)
    return get_torrent_cut_enabled()


def ensure_ip_ban_plugin_off() -> None:
    if not REMNAWAVE_PLUGIN_UUID:
        return
    payload = remnawave_request("GET", f"/api/node-plugins/{REMNAWAVE_PLUGIN_UUID}")
    config = (payload.get("response") or {}).get("pluginConfig")
    if not isinstance(config, dict):
        return
    tb = dict(config.get("torrentBlocker") or {})
    if not tb.get("enabled"):
        return
    ignore = dict(tb.get("ignoreLists") or {})
    ignore.setdefault("ip", [])
    ignore.setdefault("userId", [])
    tb["enabled"] = False
    tb["ignoreLists"] = ignore
    tb["blockDuration"] = int(tb.get("blockDuration") or REMNAWAVE_BLOCK_DURATION)
    config["torrentBlocker"] = tb
    remnawave_request(
        "PATCH",
        "/api/node-plugins/",
        {"uuid": REMNAWAVE_PLUGIN_UUID, "pluginConfig": config},
    )
    remnawave_request(
        "POST",
        "/api/node-plugins/actions/sync",
        {"uuid": REMNAWAVE_PLUGIN_UUID},
    )


def lookup_user_by_id(user_id: str | int) -> dict | None:
    try:
        payload = remnawave_request("GET", f"/api/users/{user_id}")
        user = payload.get("response")
        return user if isinstance(user, dict) else None
    except Exception as exc:
        log.warning("user lookup %s failed: %s", user_id, exc)
        return None


_ACCESS_TORRENT_RE = re.compile(
    r"^(?P<ts>\S+ \S+)\s+from\s+(?:tcp:|udp:)?(?P<source>\S+)\s+"
    r"(?P<action>accepted|rejected)\s+(?P<dest>\S+)\s+"
    r"\[(?P<inbound>[^\]>]+)>>(?P<outbound>[^\]]+)\]\s+email:\s*(?P<email>\S+)",
    re.IGNORECASE,
)


def parse_torrent_cut_line(line: str) -> dict | None:
    if "TORRENT_CUT" not in line:
        return None
    m = _ACCESS_TORRENT_RE.search(line.strip())
    if not m:
        # Fallback: at least grab email + outbound
        if ">> TORRENT_CUT" not in line and ">>TORRENT_CUT" not in line.replace(" ", ""):
            if "TORRENT_CUT" not in line:
                return None
        email_m = re.search(r"email:\s*(\S+)", line)
        if not email_m:
            return None
        return {
            "ts": line[:26].strip(),
            "source": "?",
            "action": "?",
            "dest": "?",
            "inbound": "?",
            "outbound": "TORRENT_CUT",
            "email": email_m.group(1),
            "raw": line.strip(),
        }
    return {
        "ts": m.group("ts"),
        "source": m.group("source"),
        "action": m.group("action"),
        "dest": m.group("dest"),
        "inbound": m.group("inbound").strip(),
        "outbound": m.group("outbound").strip(),
        "email": m.group("email"),
        "raw": line.strip(),
    }


def load_alert_state() -> dict:
    path = Path(TORRENT_ALERT_STATE_FILE)
    try:
        if path.exists():
            data = json.loads(path.read_text())
            if isinstance(data, dict):
                return data
    except Exception as exc:
        log.warning("alert state read failed: %s", exc)
    return {"inode": None, "offset": 0, "last_alert_by_user": {}}


def save_alert_state(state: dict) -> None:
    path = Path(TORRENT_ALERT_STATE_FILE)
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(state))
    except Exception as exc:
        log.warning("alert state write failed: %s", exc)


def format_torrent_alert(hit: dict, user: dict | None) -> str:
    username = (user or {}).get("username") or "—"
    user_id = (user or {}).get("id") or hit.get("email") or "—"
    status = (user or {}).get("status") or "—"
    short = (user or {}).get("shortUuid") or "—"
    return (
        "<b>🚨 Torrent / P2P детект</b>\n\n"
        f"👤 User: <code>{esc(str(username))}</code>\n"
        f"🆔 ID: <code>{esc(str(user_id))}</code>\n"
        f"📎 shortUuid: <code>{esc(str(short))}</code>\n"
        f"📶 Status: <code>{esc(str(status))}</code>\n\n"
        f"⏱ {esc(str(hit.get('ts') or '—'))}\n"
        f"📥 Inbound: <code>{esc(str(hit.get('inbound') or '—'))}</code>\n"
        f"🎯 Dest: <code>{esc(str(hit.get('dest') or '—'))}</code>\n"
        f"🔌 Action: <code>{esc(str(hit.get('action') or '—'))}</code> → "
        f"<code>{esc(str(hit.get('outbound') or 'TORRENT_CUT'))}</code>\n\n"
        "IP не баним — только срез bittorrent → TORRENT_CUT."
    )


async def send_torrent_alerts(application: Application, hits: list[dict]) -> None:
    if not hits or not ALLOWED_CHAT_IDS:
        return
    for hit in hits:
        user = None
        email = hit.get("email")
        if email and str(email).isdigit():
            user = await asyncio.to_thread(lookup_user_by_id, email)
        text = format_torrent_alert(hit, user)
        for chat_id in ALLOWED_CHAT_IDS:
            try:
                await application.bot.send_message(
                    chat_id=chat_id,
                    text=text,
                    parse_mode="HTML",
                    disable_web_page_preview=True,
                )
            except Exception as exc:
                log.warning("alert send to %s failed: %s", chat_id, exc)


def scan_torrent_access_log(state: dict) -> tuple[list[dict], dict]:
    path = Path(TORRENT_ACCESS_LOG)
    if not path.exists():
        return [], state

    st = path.stat()
    inode = getattr(st, "st_ino", None)
    size = st.st_size
    offset = int(state.get("offset") or 0)
    if state.get("inode") != inode or offset > size:
        offset = 0

    hits: list[dict] = []
    with path.open("r", errors="replace") as fh:
        fh.seek(offset)
        for line in fh:
            parsed = parse_torrent_cut_line(line)
            if not parsed:
                continue
            hits.append(parsed)
        new_offset = fh.tell()

    now = int(time.time())
    last_map = dict(state.get("last_alert_by_user") or {})
    filtered: list[dict] = []
    for hit in hits:
        key = str(hit.get("email") or hit.get("raw"))
        prev = int(last_map.get(key) or 0)
        if now - prev < TORRENT_ALERT_COOLDOWN_SEC:
            continue
        last_map[key] = now
        filtered.append(hit)

    # prune old cooldown entries
    last_map = {
        k: v
        for k, v in last_map.items()
        if now - int(v) < max(TORRENT_ALERT_COOLDOWN_SEC * 3, 3600)
    }
    state = {
        "inode": inode,
        "offset": new_offset,
        "last_alert_by_user": last_map,
    }
    return filtered, state


async def torrent_alert_watcher(application: Application) -> None:
    log.info(
        "torrent alert watcher started (log=%s poll=%ss cooldown=%ss)",
        TORRENT_ACCESS_LOG,
        TORRENT_ALERT_POLL_SEC,
        TORRENT_ALERT_COOLDOWN_SEC,
    )
    # Skip historical lines on first start
    state = load_alert_state()
    path = Path(TORRENT_ACCESS_LOG)
    if path.exists() and not state.get("offset"):
        st = path.stat()
        state = {
            "inode": getattr(st, "st_ino", None),
            "offset": st.st_size,
            "last_alert_by_user": {},
        }
        save_alert_state(state)

    while True:
        try:
            hits, state = await asyncio.to_thread(scan_torrent_access_log, state)
            save_alert_state(state)
            if hits:
                await send_torrent_alerts(application, hits)
        except Exception:
            log.exception("torrent alert watcher iteration failed")
        await asyncio.sleep(max(5, TORRENT_ALERT_POLL_SEC))


def torrent_keyboard(cut_on: bool) -> InlineKeyboardMarkup:
    toggle_label = "🔴 Выключить срез" if cut_on else "🟢 Включить срез"
    toggle_data = "torrent:off" if cut_on else "torrent:on"
    return InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton(toggle_label, callback_data=toggle_data),
                InlineKeyboardButton("🔄 Обновить", callback_data="torrent:refresh"),
            ]
        ]
    )


def torrent_status_text(cut_on: bool, note: str = "") -> str:
    state = "🟢 <b>ВКЛ</b>" if cut_on else "🔴 <b>ВЫКЛ</b>"
    text = (
        "<b>✂️ Срез bittorrent</b>\n\n"
        f"Статус: {state}\n"
        "Без бана юзеров и без бана IP.\n"
        "Правило: <code>bittorrent → TORRENT_CUT</code>.\n"
        "Алерты в этот чат при детекте (из access.log)."
    )
    if note:
        text += f"\n\n{esc(note)}"
    return text


async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.message:
        return
    user = update.effective_user
    tg_id = str(user.id) if user else ""
    display = ((user.full_name if user else "") or "").strip()
    uname = (user.username if user else "") or ""

    if is_allowed(update):
        try:
            await context.bot.set_chat_menu_button(menu_button=MenuButtonCommands())
        except Exception as exc:
            log.warning("reset menu button failed: %s", exc)
        try:
            await open_awg_clients_home(update.message, context, edit=False)
        except Exception as exc:
            log.exception("AWG home on /start failed")
            await update.message.reply_text(
                f"AWG панель: <code>{esc(str(exc))}</code>",
                parse_mode="HTML",
                reply_markup=ops_keyboard(),
            )
        return

    if not AWG_AUTO_CREATE_USERS:
        await deny(update)
        return
    if not awg_configured():
        await update.message.reply_text(
            "Автосоздание пользователей AWG сейчас недоступно. Напишите администратору."
        )
        return
    try:
        panel_user, created_password = await asyncio.to_thread(
            awg_ensure_user, tg_id, uname, display
        )
    except Exception as exc:
        log.exception("AWG auto-create failed for %s", tg_id)
        await update.message.reply_text(
            "Не удалось создать пользователя в AWG-панели:\n"
            f"<code>{esc(str(exc))}</code>",
            parse_mode="HTML",
        )
        return

    username = esc(str(panel_user.get("username") or "?"))
    if created_password:
        await update.message.reply_text(
            "👋 Аккаунт в AWG-панели создан.\n\n"
            f"Логин: <code>{username}</code>\n"
            f"Пароль: <code>{esc(created_password)}</code>\n"
            f"Панель: {esc(AWG_PANEL_PUBLIC_URL)}\n\n"
            "Ops-команды сервера доступны только администратору.",
            parse_mode="HTML",
            disable_web_page_preview=True,
        )
    else:
        await update.message.reply_text(
            "Ваш Telegram уже привязан к пользователю AWG-панели "
            f"<code>{username}</code>.\n"
            f"Панель: {esc(AWG_PANEL_PUBLIC_URL)}",
            parse_mode="HTML",
            disable_web_page_preview=True,
        )


async def cmd_panel(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update):
        await deny(update)
        return
    if not update.message:
        return
    try:
        await open_awg_clients_home(update.message, context, edit=False)
    except Exception as exc:
        await update.message.reply_text(
            f"AWG панель: <code>{esc(str(exc))}</code>",
            parse_mode="HTML",
            reply_markup=ops_keyboard(),
        )

async def cmd_myid(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    chat_id = update.effective_chat.id if update.effective_chat else "?"
    user_id = update.effective_user.id if update.effective_user else "?"
    allowed = "да" if is_allowed(update) else "нет"
    await update.message.reply_text(
        f"chat_id: <code>{esc(str(chat_id))}</code>\n"
        f"user_id: <code>{esc(str(user_id))}</code>\n"
        f"доступ: {allowed}",
        parse_mode="HTML",
    )


async def cmd_status(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update):
        await deny(update)
        return
    await update.message.reply_text("⏳ Собираю статус…")
    await update.message.reply_text(
        build_status_text(),
        parse_mode="HTML",
        disable_web_page_preview=True,
    )


async def cmd_reboot(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update):
        await deny(update)
        return
    await update.message.reply_text(
        "Перезагрузить FI 🇫🇮?\nПодтвердите кнопкой ниже.",
        reply_markup=confirm_keyboard(),
    )


async def cmd_torrent(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update):
        await deny(update)
        return
    if not remnawave_configured():
        await update.message.reply_text(
            "Remnawave API не настроен (REMNAWAVE_API_TOKEN / NODE)."
        )
        return
    try:
        cut_on = get_torrent_cut_enabled()
    except Exception as exc:
        await update.message.reply_text(
            f"Не удалось получить статус среза:\n<code>{esc(str(exc))}</code>",
            parse_mode="HTML",
        )
        return
    await update.message.reply_text(
        torrent_status_text(cut_on),
        parse_mode="HTML",
        reply_markup=torrent_keyboard(cut_on),
    )



async def _edit_or_answer(query, text: str, reply_markup=None, parse_mode="HTML") -> None:
    try:
        await query.edit_message_text(text, reply_markup=reply_markup, parse_mode=parse_mode, disable_web_page_preview=True)
    except Exception:
        await query.message.reply_text(text, reply_markup=reply_markup, parse_mode=parse_mode, disable_web_page_preview=True)


async def on_ops_awg_callback(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    query = update.callback_query
    if not query:
        return
    if not is_allowed(update):
        await query.answer("Доступ запрещён", show_alert=True)
        return
    data = query.data or ""
    await query.answer()

    if data in ("ops:menu", "ops:noop"):
        await _edit_or_answer(query, HELP_TEXT, ops_keyboard(), parse_mode=None)
        return
    if data == "ops:status":
        await _edit_or_answer(query, "⏳ Собираю статус…", ops_keyboard(), parse_mode=None)
        await query.message.reply_text(build_status_text(), parse_mode="HTML", disable_web_page_preview=True, reply_markup=ops_keyboard())
        return
    if data == "ops:torrent":
        if not remnawave_configured():
            await _edit_or_answer(query, "Remnawave API не настроен.", ops_keyboard(), parse_mode=None)
            return
        try:
            cut_on = await asyncio.to_thread(get_torrent_cut_enabled)
        except Exception as exc:
            await _edit_or_answer(query, f"Ошибка: <code>{esc(str(exc))}</code>", ops_keyboard())
            return
        await _edit_or_answer(query, torrent_status_text(cut_on), torrent_keyboard(cut_on))
        return
    if data == "ops:reboot":
        await _edit_or_answer(query, "Перезагрузить FI 🇫🇮?\nПодтвердите кнопкой ниже.", confirm_keyboard(), parse_mode=None)
        return
    if data == "ops:myid":
        chat_id = update.effective_chat.id if update.effective_chat else "?"
        user_id = update.effective_user.id if update.effective_user else "?"
        await _edit_or_answer(
            query,
            f"chat_id: <code>{esc(str(chat_id))}</code>\nuser_id: <code>{esc(str(user_id))}</code>",
            ops_keyboard(),
        )
        return

    if data == "awg:menu":
        try:
            await open_awg_clients_home(query, context, edit=True)
        except Exception as exc:
            await _edit_or_answer(query, f"AWG панель: <code>{esc(str(exc))}</code>", ops_keyboard())
        return
    if data == "awg:servers":
        try:
            awg_data = await asyncio.to_thread(load_awg_data)
        except Exception as exc:
            await _edit_or_answer(query, f"Не читать servers: <code>{esc(str(exc))}</code>", awg_main_keyboard())
            return
        servers = awg_data.get("servers") or []
        await _edit_or_answer(
            query,
            f"🖥 <b>Серверы</b> ({len(servers)})\nВыберите сервер:",
            awg_servers_keyboard(awg_data),
        )
        return
    if data == "awg:users":
        try:
            total, users = await asyncio.to_thread(awg_list_users_brief)
        except Exception as exc:
            await _edit_or_answer(query, f"Ошибка users: <code>{esc(str(exc))}</code>", awg_main_keyboard())
            return
        lines = [f"👤 <b>Пользователи</b> ({total})"]
        for u in users[:30]:
            tg = u.get("telegramId") or "—"
            en = "✅" if u.get("enabled", True) else "⛔"
            lines.append(f"{en} <code>{esc(str(u.get('username')))}</code> · tg:{esc(str(tg))}")
        await _edit_or_answer(query, "\n".join(lines), awg_main_keyboard())
        return

    m = re.match(r"^awg:srv:(\d+)$", data)
    if m:
        sid = int(m.group(1))
        try:
            server = await asyncio.to_thread(awg_refresh_server, sid)
        except Exception as exc:
            await _edit_or_answer(query, f"Ошибка сервера: <code>{esc(str(exc))}</code>", awg_main_keyboard())
            return
        name = esc(str(server.get("name") or server.get("host") or sid))
        host = esc(str(server.get("host") or "?"))
        user = esc(str(server.get("username") or "?"))
        port = esc(str(server.get("ssh_port") or 22))
        conn = server.get("_connection")
        conn_line = f"\nSSH: <code>{esc(str(conn))}</code>" if conn else ""
        text = (
            f"🖥 <b>{name}</b>\n"
            f"Host: <code>{host}</code>\n"
            f"SSH: <code>{user}@{host}:{port}</code>{conn_line}\n\n"
            f"<b>Протоколы</b>:"
        )
        await _edit_or_answer(query, text, awg_protocols_keyboard(sid, server))
        return

    m = re.match(r"^awg:proto:(\d+):(.+)$", data)
    if m:
        sid = int(m.group(1)); proto = m.group(2)
        try:
            server = await asyncio.to_thread(awg_refresh_server, sid)
            info = (server.get("protocols") or {}).get(proto) or {}
            clients = await asyncio.to_thread(awg_list_clients, sid, proto)
            context.user_data[f"awg_clients:{sid}:{proto}"] = clients
        except Exception as exc:
            await _edit_or_answer(query, f"Ошибка протокола: <code>{esc(str(exc))}</code>", awg_main_keyboard())
            return
        label = esc(str(info.get("display_name") or proto))
        status = "🟢 running" if info.get("container_running") is True else (
            "🔴 stopped" if info.get("container_running") is False else "⚪ unknown"
        )
        lines_out = [
            f"🔌 <b>{label}</b> (<code>{esc(proto)}</code>)",
            f"Сервер: <b>{esc(str(server.get('name') or server.get('host')))}</b>",
            f"Статус: <b>{status}</b>",
        ]
        for key, title in (
            ("container_name", "Container"),
            ("port", "Port"),
            ("peers_count", "Peers"),
            ("subnet", "Subnet"),
        ):
            if info.get(key) not in (None, ""):
                lines_out.append(f"{title}: <code>{esc(str(info.get(key)))}</code>")
        if info.get("status_error"):
            lines_out.append(f"Error: <code>{esc(str(info.get('status_error')))}</code>")
        lines_out.append("")
        lines_out.append(f"👥 Клиенты: <b>{len(clients)}</b>")
        # protocol screen: + new client, client list, refresh, back
        await _edit_or_answer(
            query,
            "\n".join(lines_out),
            awg_clients_keyboard(sid, proto, clients),
        )
        return

    m = re.match(r"^awg:clients:(\d+):(.+)$", data)
    if m:
        sid = int(m.group(1)); proto = m.group(2)
        try:
            clients = await asyncio.to_thread(awg_list_clients, sid, proto)
        except Exception as exc:
            await _edit_or_answer(query, f"Ошибка клиентов: <code>{esc(str(exc))}</code>", awg_protocol_keyboard(sid, proto))
            return
        context.user_data[f"awg_clients:{sid}:{proto}"] = clients
        lines = [f"👥 <b>Клиенты</b> ({len(clients)}) · <code>{esc(proto)}</code>"]
        for c in clients[:40]:
            if isinstance(c, dict):
                lines.append(f"• {esc(str(c.get('name') or c.get('id') or c))}")
            else:
                lines.append(f"• {esc(str(c))}")
        if not clients:
            lines.append("Пусто")
        await _edit_or_answer(query, "\n".join(lines), awg_clients_keyboard(sid, proto, clients))
        return

    m = re.match(r"^awg:addclient:(\d+):(.+)$", data)
    if m:
        sid = int(m.group(1)); proto = m.group(2)
        context.user_data["pending_add_client"] = {"sid": sid, "proto": proto}
        await _edit_or_answer(
            query,
            f"➕ Новый клиент для <code>{esc(proto)}</code>\n"
            "Пришлите имя клиента одним сообщением.\n"
            "Отмена: /cancel",
            awg_clients_keyboard(sid, proto),
        )
        return



    m = re.match(r"^awg:cli:(\d+):([^:]+):(\d+)$", data)
    if m:
        sid = int(m.group(1)); proto = m.group(2); idx = int(m.group(3))
        clients = context.user_data.get(f"awg_clients:{sid}:{proto}")
        if clients is None:
            try:
                clients = await asyncio.to_thread(awg_list_clients, sid, proto)
                context.user_data[f"awg_clients:{sid}:{proto}"] = clients
            except Exception as exc:
                await _edit_or_answer(query, f"Ошибка: <code>{esc(str(exc))}</code>", awg_protocol_keyboard(sid, proto))
                return
        if idx < 0 or idx >= len(clients):
            await _edit_or_answer(query, "Клиент не найден, обновите список.", awg_clients_keyboard(sid, proto, clients))
            return
        client = clients[idx] if isinstance(clients[idx], dict) else {"name": str(clients[idx]), "id": str(clients[idx])}
        name = esc(str(client.get("name") or "?"))
        cid = esc(str(client.get("id") or "?"))
        await _edit_or_answer(
            query,
            f"👤 <b>{name}</b>\nID: <code>{cid}</code>\nПротокол: <code>{esc(proto)}</code>",
            awg_client_menu_keyboard(sid, proto, idx),
        )
        return

    m = re.match(r"^awg:del:(\d+):([^:]+):(\d+)$", data)
    if m:
        sid = int(m.group(1)); proto = m.group(2); idx = int(m.group(3))
        clients = context.user_data.get(f"awg_clients:{sid}:{proto}") or []
        if 0 <= idx < len(clients):
            raw = clients[idx]
            client = raw if isinstance(raw, dict) else {"name": str(raw), "id": str(raw)}
        else:
            client = {}
        name = esc(str(client.get("name") or f"#{idx}"))
        await _edit_or_answer(
            query,
            f"🗑 Удалить клиента <b>{name}</b>?",
            awg_client_delete_confirm_keyboard(sid, proto, idx),
        )
        return

    m = re.match(r"^awg:delok:(\d+):([^:]+):(\d+)$", data)
    if m:
        sid = int(m.group(1)); proto = m.group(2); idx = int(m.group(3))
        clients = context.user_data.get(f"awg_clients:{sid}:{proto}")
        if clients is None:
            clients = await asyncio.to_thread(awg_list_clients, sid, proto)
        if idx < 0 or idx >= len(clients):
            await _edit_or_answer(query, "Клиент не найден.", awg_clients_keyboard(sid, proto, clients or []))
            return
        raw = clients[idx]
        client = raw if isinstance(raw, dict) else {"id": str(raw), "name": str(raw)}
        cid = str(client.get("id") or "")
        name = str(client.get("name") or cid)
        try:
            await asyncio.to_thread(awg_remove_client, sid, proto, cid)
            clients = await asyncio.to_thread(awg_list_clients, sid, proto)
            context.user_data[f"awg_clients:{sid}:{proto}"] = clients
            await _edit_or_answer(
                query,
                f"✅ Удалён: <code>{esc(name)}</code>\n\n👥 Клиенты: {len(clients)}",
                awg_clients_keyboard(sid, proto, clients),
            )
        except Exception as exc:
            await _edit_or_answer(
                query,
                f"❌ Не удалось удалить:\n<code>{esc(str(exc))}</code>",
                awg_client_menu_keyboard(sid, proto, idx),
            )
        return

    m = re.match(r"^awg:cfg:(\d+):([^:]+):(\d+)$", data)
    if m:
        sid = int(m.group(1)); proto = m.group(2); idx = int(m.group(3))
        clients = context.user_data.get(f"awg_clients:{sid}:{proto}")
        if clients is None:
            clients = await asyncio.to_thread(awg_list_clients, sid, proto)
            context.user_data[f"awg_clients:{sid}:{proto}"] = clients
        if idx < 0 or idx >= len(clients):
            await _edit_or_answer(query, "Клиент не найден.", awg_clients_keyboard(sid, proto, clients or []))
            return
        raw = clients[idx]
        client = raw if isinstance(raw, dict) else {"id": str(raw), "name": str(raw)}
        cid = str(client.get("id") or "")
        name = str(client.get("name") or "client")
        try:
            result = await asyncio.to_thread(awg_get_client_config, sid, proto, cid)
            config = str(result.get("config") or "").strip()
            if not config:
                await query.message.reply_text("Панель не вернула config.")
            else:
                safe_name = "".join(ch if ch.isalnum() or ch in "-_." else "_" for ch in name) or "client"
                doc = InputFile(io.BytesIO(config.encode("utf-8")), filename=f"{safe_name}.conf")
                await query.message.reply_document(document=doc, caption=f"Конфиг AmneziaWG: {name}")
            await _edit_or_answer(
                query,
                f"👤 <b>{esc(name)}</b>\nID: <code>{esc(cid)}</code>",
                awg_client_menu_keyboard(sid, proto, idx),
            )
        except Exception as exc:
            await _edit_or_answer(
                query,
                f"❌ Конфиг:\n<code>{esc(str(exc))}</code>",
                awg_client_menu_keyboard(sid, proto, idx),
            )
        return


async def on_pending_add_client(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.message or not is_allowed(update):
        return
    pending = context.user_data.get("pending_add_client")
    if not pending:
        return
    name = (update.message.text or "").strip()
    if name.startswith("/"):
        return
    sid = int(pending.get("sid", -1))
    proto = str(pending.get("proto") or "")
    context.user_data.pop("pending_add_client", None)
    await update.message.reply_text(f"⏳ Создаю клиента <code>{esc(name)}</code>…", parse_mode="HTML")
    try:
        result = await asyncio.to_thread(awg_add_client, sid, proto, name)
    except Exception as exc:
        log.exception("add client failed")
        await update.message.reply_text(
            f"❌ Не удалось создать клиента:\n<code>{esc(str(exc))}</code>",
            parse_mode="HTML",
            reply_markup=awg_clients_keyboard(sid, proto),
        )
        return
    client_name = esc(str(result.get("client_name") or name))
    client_id = esc(str(result.get("client_id") or "?"))
    client_ip = esc(str(result.get("client_ip") or "?"))
    config = str(result.get("config") or "").strip()
    await update.message.reply_text(
        f"✅ Клиент создан\n"
        f"Имя: <code>{client_name}</code>\n"
        f"ID: <code>{client_id}</code>\n"
        f"IP: <code>{client_ip}</code>",
        parse_mode="HTML",
        reply_markup=awg_clients_keyboard(sid, proto),
    )
    if config:
        safe_name = "".join(ch if ch.isalnum() or ch in "-_." else "_" for ch in str(result.get("client_name") or name)) or "client"
        filename = f"{safe_name}.conf"
        doc = InputFile(io.BytesIO(config.encode("utf-8")), filename=filename)
        await update.message.reply_document(
            document=doc,
            caption=f"Конфиг AmneziaWG: {client_name}",
        )
    else:
        await update.message.reply_text(
            "Клиент создан, но панель не вернула config. Откройте его в AWG-панели.",
            reply_markup=awg_clients_keyboard(sid, proto),
        )


async def cmd_cancel(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.message:
        return
    if context.user_data.pop("pending_add_client", None):
        await update.message.reply_text("Отменено.", reply_markup=ops_keyboard())
    else:
        await update.message.reply_text("Нечего отменять.")


async def on_reboot_callback(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> None:
    query = update.callback_query
    await query.answer()
    if not is_allowed(update):
        await query.edit_message_text("Доступ запрещён.")
        return
    data = query.data or ""
    if data == "reboot:cancel":
        await query.edit_message_text("Отменено.")
        return
    if data == "reboot:fi:yes":
        await query.edit_message_text("🔄 Перезагрузка FI…")
        reboot_local()
        return
    await query.edit_message_text("Неизвестная команда.")


async def on_torrent_callback(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> None:
    query = update.callback_query
    if not is_allowed(update):
        await query.answer("Доступ запрещён", show_alert=True)
        return
    data = query.data or ""
    if data == "torrent:refresh":
        await query.answer("Обновляю…")
        try:
            cut_on = get_torrent_cut_enabled()
            await query.edit_message_text(
                torrent_status_text(cut_on),
                parse_mode="HTML",
                reply_markup=torrent_keyboard(cut_on),
            )
        except Exception as exc:
            await query.edit_message_text(
                f"Ошибка чтения статуса:\n<code>{esc(str(exc))}</code>",
                parse_mode="HTML",
            )
        return

    if data not in {"torrent:on", "torrent:off"}:
        await query.answer("Неизвестная команда", show_alert=True)
        return

    want_on = data == "torrent:on"
    await query.answer("Включаю срез…" if want_on else "Выключаю срез…")
    await query.edit_message_text(
        "⏳ Применяю срез "
        f"{'ВКЛ' if want_on else 'ВЫКЛ'} (обновление профиля + soft restart)…"
    )
    try:
        cut_on = set_torrent_cut_enabled(want_on)
        note = (
            "Готово."
            if cut_on == want_on
            else "Статус после применения отличается — проверьте панель."
        )
        await query.edit_message_text(
            torrent_status_text(cut_on, note=note),
            parse_mode="HTML",
            reply_markup=torrent_keyboard(cut_on),
        )
    except Exception as exc:
        await query.edit_message_text(
            f"Не удалось переключить срез:\n<code>{esc(str(exc))}</code>",
            parse_mode="HTML",
        )


def validate_config() -> None:
    if not BOT_TOKEN or BOT_TOKEN == "change_me":
        log.error("BOT_TOKEN не задан в .env")
        sys.exit(1)
    if not ALLOWED_CHAT_IDS:
        log.warning(
            "ALLOWED_CHAT_IDS пуст — бот запустится, но команды недоступны. "
            "Используйте /myid и добавьте chat_id в .env"
        )
    if not remnawave_configured():
        log.warning(
            "Remnawave API не полностью настроен — /torrent будет недоступен"
        )


async def post_init(application: Application) -> None:
    try:
        await application.bot.set_chat_menu_button(menu_button=MenuButtonCommands())
    except Exception as exc:
        log.warning("set_chat_menu_button failed: %s", exc)
    await application.bot.set_my_commands(
        [
            BotCommand("start", "Главное меню"),
            BotCommand("status", "Статус FI сервера"),
            BotCommand("torrent", "Срез bittorrent on/off"),
            BotCommand("reboot", "Перезагрузка FI"),
            BotCommand("myid", "Показать Telegram ID"),
            BotCommand("panel", "AWG панель / серверы"),
            BotCommand("help", "Справка"),
        ]
    )
    await application.bot.set_my_description(
        "Ops меню + AWG серверы. /start для кнопок."
    )
    try:
        ensure_ip_ban_plugin_off()
    except Exception as exc:
        log.warning("startup ensure IP-ban off failed: %s", exc)
    # Keep a strong reference so the task is not GC'd.
    application.bot_data["torrent_alert_task"] = asyncio.create_task(
        torrent_alert_watcher(application)
    )


def main() -> None:
    validate_config()
    app = (
        Application.builder()
        .token(BOT_TOKEN)
        .post_init(post_init)
        .build()
    )
    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("help", cmd_start))
    app.add_handler(CommandHandler("myid", cmd_myid))
    app.add_handler(CommandHandler("panel", cmd_panel))
    app.add_handler(CommandHandler("status", cmd_status))
    app.add_handler(CommandHandler("torrent", cmd_torrent))
    app.add_handler(CommandHandler("reboot", cmd_reboot))
    app.add_handler(CallbackQueryHandler(on_ops_awg_callback, pattern=r"^(ops|awg):"))
    app.add_handler(CommandHandler("cancel", cmd_cancel))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, on_pending_add_client))

    app.add_handler(CallbackQueryHandler(on_reboot_callback, pattern=r"^reboot:"))
    app.add_handler(CallbackQueryHandler(on_torrent_callback, pattern=r"^torrent:"))
    log.info("vpn-bot started, allowed chats: %s", ALLOWED_CHAT_IDS or "(none)")
    app.run_polling(drop_pending_updates=True)


if __name__ == "__main__":
    main()

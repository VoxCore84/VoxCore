"""Async SOAP client for TrinityCore worldserver."""

import re
import html
import aiohttp
from config import SOAP_HOST, SOAP_PORT, SOAP_USER, SOAP_PASS

SOAP_URL = f"http://{SOAP_HOST}:{SOAP_PORT}/"

SOAP_ENVELOPE = """<?xml version="1.0" encoding="utf-8"?>
<SOAP-ENV:Envelope
  xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"
  xmlns:ns1="urn:TC">
  <SOAP-ENV:Body>
    <ns1:executeCommand>
      <command>{command}</command>
    </ns1:executeCommand>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>"""

_RE_RESULT = re.compile(r"<result>(.*?)</result>", re.DOTALL)
_RE_FAULT = re.compile(r"<faultstring>(.*?)</faultstring>", re.DOTALL)


async def send_command(command: str, timeout: float = 10.0) -> tuple[bool, str]:
    """Send a GM command via SOAP. Returns (success, response_text)."""
    body = SOAP_ENVELOPE.format(command=html.escape(command))
    auth = aiohttp.BasicAuth(SOAP_USER, SOAP_PASS)

    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(
                SOAP_URL,
                data=body,
                auth=auth,
                headers={"Content-Type": "text/xml; charset=utf-8"},
                timeout=aiohttp.ClientTimeout(total=timeout),
            ) as resp:
                text = await resp.text()

                m = _RE_RESULT.search(text)
                if m:
                    return True, html.unescape(m.group(1)).strip()

                m = _RE_FAULT.search(text)
                if m:
                    return False, html.unescape(m.group(1)).strip()

                return False, f"Unexpected SOAP response (HTTP {resp.status})"

    except aiohttp.ClientConnectorError:
        return False, "Could not connect to worldserver (is it running?)"
    except TimeoutError:
        return False, "SOAP request timed out"
    except Exception as e:
        return False, f"SOAP error: {e}"

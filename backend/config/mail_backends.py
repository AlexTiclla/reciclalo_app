"""Backend de email que habla con la API HTTP de Resend en vez de su relay SMTP.

Render bloquea el tráfico saliente a los puertos SMTP (25/465/587) en sus
planes free: la conexión no falla con un error claro, queda colgada hasta que
gunicorn mata al worker por timeout (log engañoso: "Perhaps out of memory?").
HTTPS (443) no tiene esa restricción, así que usamos la API REST de Resend
directo con `urllib` — no hace falta el SDK de Resend para un solo POST.
"""

import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from django.conf import settings
from django.core.mail.backends.base import BaseEmailBackend

RESEND_API_URL = 'https://api.resend.com/emails'


class ResendAPIEmailBackend(BaseEmailBackend):
    def send_messages(self, email_messages):
        if not email_messages:
            return 0

        enviados = 0
        for message in email_messages:
            try:
                self._enviar(message)
                enviados += 1
            except Exception:
                if not self.fail_silently:
                    raise
        return enviados

    def _enviar(self, message) -> None:
        html = None
        for contenido, mimetype in getattr(message, 'alternatives', []):
            if mimetype == 'text/html':
                html = contenido
                break

        payload = {
            'from': message.from_email,
            'to': list(message.to),
            'subject': message.subject,
            'text': message.body,
        }
        if html:
            payload['html'] = html
        if message.cc:
            payload['cc'] = list(message.cc)
        if message.bcc:
            payload['bcc'] = list(message.bcc)

        request = Request(
            RESEND_API_URL,
            data=json.dumps(payload).encode('utf-8'),
            headers={
                'Authorization': f'Bearer {settings.RESEND_API_KEY}',
                'Content-Type': 'application/json',
            },
            method='POST',
        )
        try:
            with urlopen(request, timeout=10) as response:
                response.read()
        except HTTPError as exc:
            detalle = exc.read().decode('utf-8', errors='replace')
            raise RuntimeError(f'Resend API respondió {exc.code}: {detalle}') from exc
        except URLError as exc:
            raise RuntimeError(f'No se pudo conectar a la API de Resend: {exc.reason}') from exc

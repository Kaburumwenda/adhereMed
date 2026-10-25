"""Viewset mixin that ties clinical records to a clinic site.

Two behaviours, both opt-in per viewset:

* **create** — when the payload omits ``clinic_site``, the record is stamped with
  the clinic carried by ``X-Clinic-Site`` / ``?site=`` (the value the frontend's
  axios client sends). With no header the field stays ``NULL``, which the
  aggregation endpoints treat as HQ.
* **list** — ``?site=<id|code|hq>`` narrows the queryset to that clinic. ``?site=all``
  (or omitting it) keeps the tenant-wide view. A *header* never filters a list:
  the frontend sends ``X-Clinic-Site`` on every request, and silently hiding
  records from other clinics would surprise staff who need to look a patient up
  network-wide.

The stamping happens by amending the parsed request payload *before* the
create runs, so viewsets that define their own ``perform_create`` (nurse
auto-assign, doctor auto-assign, etc.) keep working untouched.
"""
from __future__ import annotations

from clinic_sites.utils import resolve_site, scope_to_site


class ClinicSiteScopedMixin:
    """Stamp ``clinic_site`` on create and scope lists by ``?site=``."""

    #: Name of the FK on the model (all scoped models use ``clinic_site``).
    clinic_site_field = 'clinic_site'

    # ── request helpers ─────────────────────────────────────────────
    def _query_site(self):
        """Site from ``?site=`` only — used for list filtering."""
        request = getattr(self, 'request', None)
        if request is None:
            return None
        try:
            value = request.query_params.get('site') or request.query_params.get('clinic_site')
        except AttributeError:
            return None
        if value in (None, '', 'all', 'any'):
            return None
        return resolve_site(value)

    def _request_site(self):
        """Site from ``?site=`` or the ``X-Clinic-Site`` header — used for stamping."""
        request = getattr(self, 'request', None)
        if request is None:
            return None
        site = self._query_site()
        if site is not None:
            return site
        value = request.headers.get('X-Clinic-Site')
        if value in (None, '', 'all', 'any'):
            return None
        return resolve_site(value)

    # ── queryset scoping ────────────────────────────────────────────
    def get_queryset(self):
        qs = super().get_queryset()
        site = self._query_site()
        if site is None:
            return qs
        return scope_to_site(qs, site, field=self.clinic_site_field)

    # ── create stamping ─────────────────────────────────────────────
    def create(self, request, *args, **kwargs):
        site = self._request_site()
        if site is not None:
            try:
                payload = request.data
                has_value = (
                    hasattr(payload, 'get') and payload.get(self.clinic_site_field)
                )
                if not has_value and self._model_has_site():
                    # ``request.data`` may be a QueryDict (immutable); rebuild
                    # it and swap the parsed payload DRF reads from.
                    try:
                        mutable = payload.copy()
                    except AttributeError:
                        mutable = dict(payload)
                    mutable[self.clinic_site_field] = site.id
                    request._full_data = mutable
            except Exception:  # noqa: BLE001 - never break a create over stamping
                pass
        return super().create(request, *args, **kwargs)

    def _model_has_site(self) -> bool:
        model = getattr(getattr(self, 'queryset', None), 'model', None)
        if model is None:
            try:
                model = self.get_queryset().model
            except Exception:  # noqa: BLE001
                return False
        if model is None:
            return False
        return any(f.name == self.clinic_site_field for f in model._meta.get_fields())

"""Multi-clinic support for clinic tenants.

A clinic *tenant* is the commercial organisation; a :class:`ClinicSite` is one
physical clinic (the HQ plus any branches / satellites / outreach units).

Existing installations are single-clinic: every record created before this app
existed is attributed to the tenant's HQ site, which is bootstrapped from the
existing ``pharmacy_profile.PharmacyDetail`` facility profile (see the
``assign_hq_site`` management command).
"""

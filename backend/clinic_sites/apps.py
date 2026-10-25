from django.apps import AppConfig


class ClinicSitesConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'clinic_sites'
    verbose_name = 'Clinic Sites'

    def ready(self):
        from config.cache import register_invalidation

        register_invalidation(('clinic.network',), *self.get_models())

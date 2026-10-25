from django.apps import AppConfig


class ClinicCatalogConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'clinic_catalog'
    verbose_name = 'Clinic Catalog'

    def ready(self):
        from config.cache import register_invalidation

        register_invalidation(('clinic.catalog',), *self.get_models())

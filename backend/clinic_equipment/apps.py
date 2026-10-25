from django.apps import AppConfig


class ClinicEquipmentConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'clinic_equipment'
    verbose_name = 'Clinic equipment'

    def ready(self):
        from config.cache import register_invalidation

        register_invalidation(('clinic.equipment',), *self.get_models())

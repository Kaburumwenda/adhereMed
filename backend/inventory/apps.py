from django.apps import AppConfig


class InventoryConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'inventory'

    def ready(self):
        from config.cache import register_invalidation

        register_invalidation(('ims.dashboard',), *self.get_models())

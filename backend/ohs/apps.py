from django.apps import AppConfig


class OhsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'ohs'
    verbose_name = 'Occupational Health & Safety'

    def ready(self):
        from config.cache import register_invalidation

        register_invalidation(('ohsms.dashboard',), *self.get_models())

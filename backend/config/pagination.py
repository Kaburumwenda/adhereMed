from rest_framework.pagination import PageNumberPagination


class StandardPagination(PageNumberPagination):
    """Default pagination that honours `?page_size=` from the client."""
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 5000

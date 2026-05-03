from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('orders', views.PurchaseOrderViewSet, basename='purchaseorder')
router.register('grns', views.GoodsReceivedNoteViewSet, basename='goodsreceivednote')

urlpatterns = [
    path('', include(router.urls)),
]

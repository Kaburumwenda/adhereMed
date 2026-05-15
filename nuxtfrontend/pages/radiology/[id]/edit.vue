<script setup>
const route = useRoute()
navigateTo(`/radiology/orders/${route.params.id}/edit`, { replace: true })
</script>

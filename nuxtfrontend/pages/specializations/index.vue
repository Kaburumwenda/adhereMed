<template>
  <ResourceListPage
    :resource="r"
    title="Specializations"
    icon="mdi-stethoscope"
    :headers="headers"
    create-path="/specializations/new"
    create-label="New Specialization"
    singular="specialization"
    :detail-path="(p) => `/specializations/${p.id}/edit`"
    :edit-path="(p) => `/specializations/${p.id}/edit`"
  />
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const r = useResource('/doctors/specializations/')
const headers = [
  { title: 'Name', key: 'name' },
  { title: 'Description', key: 'description' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 140 }
]
</script>

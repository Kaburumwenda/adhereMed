<template>
  <div class="relative flex min-h-screen flex-col overflow-x-clip">
    <AppHeader />
    <main class="flex-1">
      <slot />
    </main>
    <AppFooter />
  </div>
</template>

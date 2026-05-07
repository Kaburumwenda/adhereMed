import { defineStore } from 'pinia'

export const useCartStore = defineStore('pharmacy_cart', {
  state: () => ({
    pharmacyId: null,
    pharmacyName: '',
    items: [] // {id, name, price, quantity, image_url}
  }),
  getters: {
    count: (s) => s.items.reduce((n, i) => n + i.quantity, 0),
    total: (s) => s.items.reduce((n, i) => n + i.quantity * Number(i.price || 0), 0)
  },
  actions: {
    setPharmacy(id, name) {
      if (this.pharmacyId !== id) {
        this.pharmacyId = id; this.pharmacyName = name; this.items = []
      }
    },
    add(p) {
      const f = this.items.find(i => i.id === p.id)
      if (f) f.quantity++
      else this.items.push({ id: p.id, name: p.name, price: p.selling_price ?? p.price, quantity: 1, image_url: p.image_url })
      this.persist()
    },
    inc(id) { const f = this.items.find(i => i.id === id); if (f) { f.quantity++; this.persist() } },
    dec(id) { const f = this.items.find(i => i.id === id); if (f) { if (f.quantity > 1) f.quantity--; else this.items = this.items.filter(i => i.id !== id); this.persist() } },
    remove(id) { this.items = this.items.filter(i => i.id !== id); this.persist() },
    clear() { this.items = []; this.persist() },
    persist() {
      if (typeof window === 'undefined') return
      localStorage.setItem('pharmacy_cart', JSON.stringify({ pharmacyId: this.pharmacyId, pharmacyName: this.pharmacyName, items: this.items }))
    },
    restore() {
      if (typeof window === 'undefined') return
      try {
        const data = JSON.parse(localStorage.getItem('pharmacy_cart') || 'null')
        if (data) { this.pharmacyId = data.pharmacyId; this.pharmacyName = data.pharmacyName; this.items = data.items || [] }
      } catch {}
    }
  }
})

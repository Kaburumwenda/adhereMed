// Google Maps JS loader (places library) — singleton across the app.
let _promise = null

export function useGoogleMaps() {
  const config = useRuntimeConfig()
  const apiKey = config.public.googleMapsApiKey

  function load() {
    if (typeof window === 'undefined') return Promise.reject(new Error('SSR'))
    if (window.google?.maps?.places) return Promise.resolve(window.google)
    if (_promise) return _promise

    if (!apiKey) {
      return Promise.reject(new Error('Missing googleMapsApiKey in runtimeConfig.public'))
    }

    _promise = new Promise((resolve, reject) => {
      const cbName = `__gmapsInit_${Date.now()}`
      window[cbName] = () => {
        delete window[cbName]
        resolve(window.google)
      }
      const script = document.createElement('script')
      script.src =
        `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(apiKey)}` +
        `&libraries=places&loading=async&callback=${cbName}`
      script.async = true
      script.defer = true
      script.onerror = () => {
        delete window[cbName]
        _promise = null
        reject(new Error('Failed to load Google Maps script'))
      }
      document.head.appendChild(script)
    })

    return _promise
  }

  // Returns place predictions for an input string.
  async function getPredictions(input, opts = {}) {
    if (!input || input.length < 2) return []
    const google = await load()
    const service = new google.maps.places.AutocompleteService()
    return new Promise((resolve) => {
      service.getPlacePredictions(
        {
          input,
          types: opts.types || ['geocode'],
          componentRestrictions: opts.country
            ? { country: opts.country }
            : undefined,
        },
        (predictions, status) => {
          if (status !== google.maps.places.PlacesServiceStatus.OK || !predictions) {
            resolve([])
          } else {
            resolve(predictions)
          }
        },
      )
    })
  }

  // Resolve a placeId to lat/lng + formatted address.
  async function getPlaceDetails(placeId) {
    const google = await load()
    return new Promise((resolve, reject) => {
      const dummy = document.createElement('div')
      const service = new google.maps.places.PlacesService(dummy)
      service.getDetails(
        { placeId, fields: ['formatted_address', 'geometry', 'name'] },
        (place, status) => {
          if (status !== google.maps.places.PlacesServiceStatus.OK || !place) {
            reject(new Error(`Place lookup failed: ${status}`))
          } else {
            resolve({
              address: place.formatted_address,
              name: place.name,
              lat: place.geometry?.location?.lat(),
              lng: place.geometry?.location?.lng(),
            })
          }
        },
      )
    })
  }

  // Reverse-geocode lat/lng → formatted address.
  async function reverseGeocode(lat, lng) {
    const google = await load()
    const geocoder = new google.maps.Geocoder()
    return new Promise((resolve, reject) => {
      geocoder.geocode({ location: { lat, lng } }, (results, status) => {
        if (status !== 'OK' || !results?.length) {
          reject(new Error(`Reverse geocode failed: ${status}`))
        } else {
          resolve(results[0].formatted_address)
        }
      })
    })
  }

  return { load, getPredictions, getPlaceDetails, reverseGeocode }
}

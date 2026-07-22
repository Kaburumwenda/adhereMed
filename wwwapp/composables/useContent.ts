// Shared content used across the marketing site.

export interface Feature {
  title: string
  desc: string
  icon: string
}

export interface Solution {
  id: string
  audience: string
  headline: string
  desc: string
  points: string[]
  icon: string
}

const ic = (path: string) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" class="h-6 w-6">${path}</svg>`

export function usePlatformFeatures(): Feature[] {
  return [
    {
      title: 'Medication Adherence',
      desc: 'Smart reminders, refill tracking and adherence scoring that keep patients on therapy and reduce avoidable readmissions.',
      icon: ic('<rect x="4" y="4" width="16" height="16" rx="5"/><path d="M5 5l14 14"/>')
    },
    {
      title: 'Telemedicine',
      desc: 'Secure video consultations, chat and remote triage connecting patients to clinicians anywhere on the continent.',
      icon: ic('<rect x="3" y="5" width="13" height="14" rx="2"/><path d="m16 10 5-3v10l-5-3"/>')
    },
    {
      title: 'Digital Prescriptions',
      desc: 'Paperless e-prescriptions routed instantly to any connected pharmacy with full audit trails and verification.',
      icon: ic('<path d="M8 3h8a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z"/><path d="M9 8h6M9 12h6M9 16h3"/>')
    },
    {
      title: 'Care Coordination',
      desc: 'Shared records and referral workflows that align doctors, hospitals, labs and homecare around one care plan.',
      icon: ic('<circle cx="12" cy="12" r="3"/><path d="M12 3v3M12 18v3M3 12h3M18 12h3M6 6l2 2M16 16l2 2M18 6l-2 2M8 16l-2 2"/>')
    },
    {
      title: 'Patient Engagement',
      desc: 'Personalised education, surveys and notifications in local languages that build trust and improve outcomes.',
      icon: ic('<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>')
    },
    {
      title: 'Population Health',
      desc: 'Real-time dashboards and predictive analytics that surface disease trends and guide public-health decisions.',
      icon: ic('<path d="M4 20V10M9 20V4M14 20v-7M19 20V8"/>')
    },
    {
      title: 'Lab & Radiology',
      desc: 'Order diagnostics, receive results and view imaging — fully integrated into the clinical workflow.',
      icon: ic('<path d="M9 3h6M10 3v6l-4 9a2 2 0 0 0 2 3h8a2 2 0 0 0 2-3l-4-9V3"/>')
    },
    {
      title: 'Insurance & Claims',
      desc: 'Automated eligibility checks, pre-authorisation and claims that cut fraud and accelerate reimbursement.',
      icon: ic('<path d="M12 3l8 3v6c0 5-4 8-8 9-4-1-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/>')
    },
    {
      title: 'Open API Platform',
      desc: 'A developer-first API layer with usage-based billing so any system can plug into the AdhereMed ecosystem.',
      icon: ic('<path d="m8 6-6 6 6 6M16 6l6 6-6 6M14 4l-4 16"/>')
    }
  ]
}

export function useSolutions(): Solution[] {
  return [
    {
      id: 'patients',
      audience: 'Patients',
      headline: 'Stay on therapy, stay connected',
      desc: 'A personal health companion for reminders, prescriptions, teleconsults and records — in one app.',
      points: ['Medication & refill reminders', 'Book teleconsultations', 'Access prescriptions & lab results', 'Insurance & payment in-app'],
      icon: ic('<circle cx="12" cy="8" r="4"/><path d="M5 21a7 7 0 0 1 14 0"/>')
    },
    {
      id: 'doctors',
      audience: 'Doctors',
      headline: 'Practise without paperwork',
      desc: 'Consult, prescribe and coordinate care from anywhere with a unified clinical workspace.',
      points: ['Video & async consultations', 'e-Prescriptions in seconds', 'Shared patient timeline', 'Referrals to any provider'],
      icon: ic('<circle cx="12" cy="7" r="3.5"/><path d="M6 21v-1a6 6 0 0 1 12 0v1"/><path d="M16 12v3a3 3 0 0 0 6 0v-2"/>')
    },
    {
      id: 'hospitals',
      audience: 'Hospitals',
      headline: 'Run a connected facility',
      desc: 'Coordinate admissions, departments and discharge with interoperable records and workflows.',
      points: ['EMR & department workflows', 'Bed & resource visibility', 'Discharge-to-homecare handoff', 'Operational dashboards'],
      icon: ic('<rect x="4" y="5" width="16" height="16" rx="2"/><path d="M12 9v6M9 12h6"/>')
    },
    {
      id: 'pharmacies',
      audience: 'Pharmacies',
      headline: 'Dispense digitally',
      desc: 'Receive verified e-prescriptions, manage stock and serve patients faster with fewer errors.',
      points: ['Inbound e-prescriptions', 'Inventory & expiry tracking', 'Adherence-driven refills', 'Insurance reconciliation'],
      icon: ic('<rect x="4" y="4" width="16" height="16" rx="5"/><path d="M5 5l14 14"/>')
    },
    {
      id: 'labs',
      audience: 'Labs & Radiology',
      headline: 'Diagnostics, fully integrated',
      desc: 'Receive orders electronically and deliver results and imaging straight into the care record.',
      points: ['Electronic test orders', 'Structured results delivery', 'Imaging & report sharing', 'Turnaround analytics'],
      icon: ic('<path d="M9 3h6M10 3v6l-4 9a2 2 0 0 0 2 3h8a2 2 0 0 0 2-3l-4-9V3"/>')
    },
    {
      id: 'insurance',
      audience: 'Insurance',
      headline: 'Smarter, faster claims',
      desc: 'Automate eligibility, authorisation and claims with real-time data to reduce fraud and cost.',
      points: ['Instant eligibility checks', 'Digital pre-authorisation', 'Automated claims', 'Fraud & risk analytics'],
      icon: ic('<path d="M12 3l8 3v6c0 5-4 8-8 9-4-1-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/>')
    },
    {
      id: 'government',
      audience: 'Government',
      headline: 'Population-scale insight',
      desc: 'Anonymised, real-time public-health intelligence to guide policy, funding and emergency response.',
      points: ['Disease surveillance', 'Coverage & access maps', 'Outbreak early warning', 'Policy impact reporting'],
      icon: ic('<path d="M12 3l9 5H3z"/><path d="M5 8v9h14V8M9 8v9M15 8v9"/>')
    },
    {
      id: 'homecare',
      audience: 'Homecare',
      headline: 'Care beyond the clinic',
      desc: 'Coordinate home visits, remote monitoring and follow-ups as a seamless extension of treatment.',
      points: ['Visit scheduling & routing', 'Remote vitals monitoring', 'Care-plan adherence', 'Caregiver collaboration'],
      icon: ic('<path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/><path d="M10 20v-5h4v5"/>')
    }
  ]
}

"""Seed a demo OHSMS tenant with a realistic safety register.

Usage
-----
    python manage.py seed_ohsms --schema acme_ohs --clear

Creates: sites, hazard categories, hazards + controls, risk assessments,
incidents + CAPA, inspections, permits, training courses + records, PPE stock,
health surveillance, exposure monitoring, observations, drills, the legal
register, audits and objectives.
"""
import random
from datetime import date, timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.db import connection
from django.utils import timezone

from accounts.models import User
from staff_profiles.models import StaffProfile
from tenants.models import Tenant

from ohs.models import (
    AssessmentFinding,
    AssessmentLabResult,
    Certification,
    ComplianceAudit,
    Contractor,
    ContractorEngagement,
    ControlMeasure,
    Document,
    DocumentAcknowledgement,
    DocumentRevision,
    EmergencyDrill,
    EquipmentDefect,
    EquipmentInspection,
    ExposureMonitoring,
    Hazard,
    HazardCategory,
    HealthAssessment,
    HealthSurveillance,
    Incident,
    IncidentAction,
    Inspection,
    InspectionItem,
    JobDemandProfile,
    LegalRequirement,
    ManagementReview,
    MeetingAttendance,
    Observation,
    PermitToWork,
    PpeIssue,
    PpeItem,
    RiskAssessment,
    RiskAssessmentItem,
    SafetyEquipment,
    SafetyMeeting,
    SafetyObjective,
    Site,
    TrainingCourse,
    TrainingRecord,
)

FIRST = ['Amina', 'Brian', 'Cynthia', 'David', 'Eunice', 'Felix', 'Grace', 'Hassan',
         'Irene', 'Joseph', 'Kevin', 'Lydia', 'Martin', 'Nancy', 'Oscar', 'Purity',
         'Quentin', 'Rachel', 'Samuel', 'Tabitha', 'Uhuru', 'Violet', 'Wycliffe', 'Yusuf']
LAST = ['Otieno', 'Kamau', 'Njoroge', 'Mwangi', 'Achieng', 'Chebet', 'Kirui', 'Mutiso',
        'Wanjiku', 'Omondi', 'Nyambura', 'Barasa', 'Wekesa', 'Kilonzo', 'Muthoni',
        'Kariuki', 'Wafula', 'Odhiambo']


def person(rng):
    return f'{rng.choice(FIRST)} {rng.choice(LAST)}'


def ref_person(rng):
    return f'EMP-{rng.randint(1000, 9999)}'


class Command(BaseCommand):
    help = 'Seed a demo Occupational Health & Safety (OHSMS) register for a tenant schema.'

    def add_arguments(self, parser):
        parser.add_argument('--schema', required=True, help='Tenant schema name')
        parser.add_argument('--clear', action='store_true', help='Delete existing OHS data first')
        parser.add_argument('--seed', type=int, default=4507, help='Random seed')
        parser.add_argument(
            '--only', default='',
            help='Comma-separated dataset keys to seed (default: all). '
                 'Prerequisites are not added automatically.',
        )

    def handle(self, *args, **options):
        schema = options['schema']
        rng = random.Random(options['seed'])
        today = date.today()

        # Demo-data API can restrict a run to selected datasets.
        only = {k.strip() for k in (options.get('only') or '').split(',') if k.strip()}

        def _want(key):
            return not only or key in only

        # Shared pools: any block may borrow these regardless of which datasets run.
        causes = ['unsafe_act', 'unsafe_condition', 'procedure', 'training', 'equipment',
                  'supervision', 'housekeeping']
        people = [(person(rng), ref_person(rng)) for _ in range(95)]

        connection.set_schema(schema)
        self.stdout.write(self.style.MIGRATE_HEADING(f'Seeding OHSMS into schema "{schema}"'))

        if options['clear']:
            for model in (
                AssessmentLabResult, AssessmentFinding, HealthAssessment,
                JobDemandProfile,
                StaffProfile,
                EquipmentDefect, EquipmentInspection, SafetyEquipment,
                Certification, ManagementReview, MeetingAttendance, SafetyMeeting,
                ContractorEngagement, Contractor, DocumentAcknowledgement,
                DocumentRevision, Document, ComplianceAudit, SafetyObjective,
                LegalRequirement, EmergencyDrill, Observation, ExposureMonitoring,
                HealthSurveillance, PpeIssue, PpeItem, TrainingRecord, TrainingCourse,
                PermitToWork, InspectionItem, Inspection, IncidentAction, Incident,
                RiskAssessmentItem, RiskAssessment, ControlMeasure, Hazard,
                HazardCategory, Site,
            ):
                model.objects.all().delete()
            self.stdout.write('  cleared existing OHS data')

        # ── Sites ────────────────────────────────────────────────────────
        if _want('sites'):
            site_specs = [
                ('Nairobi Head Office', 'NRB-HO', 'office', 'low', 'Nairobi', 'Upper Hill', 180),
                ('Mombasa Port Warehouse', 'MSA-WH', 'warehouse', 'high', 'Mombasa', 'Changamwe', 140),
                ('Kisumu Processing Plant', 'KSM-PL', 'factory', 'severe', 'Kisumu', 'Industrial Area', 220),
                ('Nakuru Distribution Hub', 'NKR-DH', 'warehouse', 'medium', 'Nakuru', 'Nakuru CBD', 95),
                ('Eldoret Fuel Terminal', 'ELD-FT', 'fuel_station', 'severe', 'Uasin Gishu', 'Eldoret', 60),
                ('Thika Road Construction Site', 'THK-CS', 'construction', 'high', 'Nairobi', 'Ruaraka', 130),
                ('Central Laboratory', 'NRB-LAB', 'laboratory', 'medium', 'Nairobi', 'KNH', 45),
            ]
            sites = []
            for name, code, stype, profile, county, addr, heads in site_specs:
                site, _ = Site.objects.get_or_create(
                    code=code,
                    defaults=dict(
                        name=name, site_type=stype, risk_profile=profile,
                        county=county, address=f'{addr}, {county}', site_manager=person(rng),
                        manager_phone=f'+2547{rng.randint(10000000, 99999999)}',
                        headcount=heads, first_aider_count=max(2, heads // 25),
                        emergency_assembly_point=f'{name.split()[0]} main gate car park',
                    ),
                )
                sites.append(site)
            self.stdout.write(f'  sites: {len(sites)}')

        # ── Hazard categories ────────────────────────────────────────────
        if _want('hazard_categories'):
            cat_specs = [
                ('Machine & mechanical', 'MEC', 'mdi-cog-outline', '#ef4444', 1),
                ('Electrical', 'ELE', 'mdi-flash-alert', '#f59e0b', 2),
                ('Chemical & hazardous substances', 'CHM', 'mdi-flask-outline', '#8b5cf6', 3),
                ('Fire & explosion', 'FIR', 'mdi-fire', '#dc2626', 4),
                ('Work at height', 'WAH', 'mdi-ladder', '#0ea5e9', 5),
                ('Manual handling & ergonomics', 'ERG', 'mdi-weight-lifter', '#14b8a6', 6),
                ('Slips, trips & falls', 'STF', 'mdi-run-fast', '#84cc16', 7),
                ('Vehicle & traffic', 'VEH', 'mdi-truck-alert', '#f97316', 8),
                ('Noise & vibration', 'NSE', 'mdi-volume-high', '#6366f1', 9),
                ('Biological & hygiene', 'BIO', 'mdi-biohazard', '#10b981', 10),
                ('Psychosocial', 'PSY', 'mdi-brain', '#ec4899', 11),
                ('Confined spaces', 'CSP', 'mdi-valve', '#64748b', 12),
            ]
            cats = {}
            for name, code, icon, color, order in cat_specs:
                category, _ = HazardCategory.objects.get_or_create(
                    code=code,
                    defaults=dict(
                        name=name, icon=icon, color=color, sort_order=order,
                        description=f'Hazards arising from {name.lower()} exposures and activities.',
                    ),
                )
                cats[code] = category
            self.stdout.write(f'  hazard categories: {len(cats)}')

        # ── Hazards + controls ───────────────────────────────────────────
        if _want('hazards'):
            hazard_specs = [
                ('Unguarded conveyor tail pulley', 'MEC', 'physical', 'Packaging line 2'),
                ('Forklift and pedestrian shared aisle', 'VEH', 'vehicle', 'Inbound goods bay'),
                ('LPG storage leaking valve', 'FIR', 'fire', 'Gas store'),
                ('Solvent decanting without extraction', 'CHM', 'chemical', 'Paint mixing room'),
                ('Working on mezzanine without guardrail', 'WAH', 'work_at_height', 'Racking level 2'),
                ('Manual pallet stacking over 20 kg', 'ERG', 'ergonomic', 'Dispatch area'),
                ('Wet floor after washdown', 'STF', 'physical', 'Production hall'),
                ('Noise above 92 dB(A) at hammer mill', 'NSE', 'physical', 'Milling section'),
                ('Exposed busbar in main switch room', 'ELE', 'electrical', 'Substation'),
                ('Confined space entry into fuel tank', 'CSP', 'confined_space', 'Fuel terminal tank 3'),
                ('Sharp instrument handling', 'BIO', 'biological', 'Laboratory bench'),
                ('Extended overtime and fatigue', 'PSY', 'psychosocial', 'Shift roster'),
                ('Hot work near solvent stores', 'FIR', 'fire', 'Maintenance workshop'),
                ('Diesel bowser hose wear', 'VEH', 'environmental', 'Fuel loading gantry'),
                ('Stacked loads exceeding racking SWL', 'MEC', 'mechanical', 'Warehouse racking'),
                ('Dust from cement offloading', 'CHM', 'chemical', 'Cement silo'),
                ('Extension ladder used as work platform', 'WAH', 'work_at_height', 'Maintenance'),
                ('Poor lighting in night-shift walkways', 'STF', 'physical', 'Night access route'),
                ('Scaffold incomplete on level 3', 'WAH', 'work_at_height', 'Block C façade'),
                ('Heavy vehicle reversing without spotter', 'VEH', 'vehicle', 'Construction gate'),
                ('Chemicals stored above eye level', 'CHM', 'chemical', 'Laboratory store'),
                ('Emergency shower blocked by pallets', 'CHM', 'chemical', 'Chemical store'),
                ('Unguarded floor opening', 'STF', 'physical', 'Mezzanine access'),
                ('Hand-arm vibration from grinders', 'NSE', 'physical', 'Fabrication shop'),
                ('Inadequate machine guarding on press', 'MEC', 'mechanical', 'Press shop'),
                ('Heat stress in boiler room', 'PSY', 'physical', 'Boiler house'),
                ('Noise exposure during compressor start', 'NSE', 'physical', 'Compressor room'),
                ('Biological spill on sample bench', 'BIO', 'biological', 'Microbiology'),
            ]
            hierarchy_cycle = ['engineering', 'administrative', 'ppe', 'elimination', 'substitution']
            statuses = ['open', 'controlled', 'monitoring', 'closed', 'open', 'open']
            hazards = []
            for idx, (title, cat_code, htype, area) in enumerate(hazard_specs, start=1):
                site = rng.choice(sites)
                sev = rng.choices([1, 2, 3, 4, 5], weights=[5, 15, 35, 30, 15])[0]
                lik = rng.choices([1, 2, 3, 4, 5], weights=[10, 25, 35, 22, 8])[0]
                status = rng.choice(statuses)
                owner = person(rng)
                hazard = Hazard.objects.create(
                    title=title,
                    description=f'{title} identified during routine site walkdown at {site.name}.',
                    hazard_type=htype,
                    category=cats[cat_code],
                    site=site,
                    area=area,
                    activity=rng.choice(['Production', 'Warehousing', 'Maintenance', 'Loading', 'Laboratory work']),
                    exposed_persons=rng.choice(['Operators', 'Contractors', 'All staff', 'Visitors', 'Maintenance crew']),
                    severity=sev, likelihood=lik,
                    residual_severity=max(1, sev - rng.choice([0, 1, 1, 2])),
                    residual_likelihood=max(1, lik - rng.choice([0, 1, 2])),
                    status=status,
                    owner_name=owner,
                    identified_on=today - timedelta(days=rng.randint(5, 500)),
                    next_review_on=today + timedelta(days=rng.randint(-60, 300)),
                    legal_reference=rng.choice([
                        'OSHA 2007 s.6', 'OSHA 2007 s.7', 'Factories Act Cap 514',
                        'ISO 45001 cl. 8.1', 'NEMA EMCA s.9', '',
                    ]),
                )
                hazards.append(hazard)
                for n in range(rng.randint(1, 3)):
                    due = today + timedelta(days=rng.randint(-90, 120))
                    st = rng.choices(
                        ['planned', 'in_progress', 'implemented', 'verified'],
                        weights=[25, 30, 25, 20],
                    )[0]
                    ControlMeasure.objects.create(
                        hazard=hazard,
                        hierarchy=hierarchy_cycle[n % len(hierarchy_cycle)],
                        description=rng.choice([
                            'Install interlocked machine guarding.',
                            'Introduce pedestrian segregation barriers and marked walkways.',
                            'Replace solvent with water-based alternative.',
                            'Add local exhaust ventilation at decanting point.',
                            'Introduce permit-to-work and pre-task briefing.',
                            'Provide fit-tested respirators with monthly checks.',
                            'Roll out manual handling training and lifting aids.',
                            'Increase housekeeping rounds to twice per shift.',
                            'Install acoustic enclosure around the hammer mill.',
                            'Lock out / tag out procedure for electrical isolation.',
                            'Restrict hot work to designated area with fire watch.',
                            'Upgrade lighting to 200 lux minimum on night routes.',
                        ]),
                        owner_name=owner, due_date=due, status=st,
                        effectiveness=rng.randint(2, 5) if st in ('implemented', 'verified') else None,
                        verified_on=due + timedelta(days=7) if st == 'verified' else None,
                        verified_by=owner if st == 'verified' else '',
                    )
            self.stdout.write(f'  hazards: {len(hazards)} ({ControlMeasure.objects.count()} controls)')

        # ── Risk assessments ─────────────────────────────────────────────
        if _want('risk_assessments'):
            ra_titles = [
                'Warehouse operations HIRA', 'Packaging line JSA', 'Chemical store HAZOP',
                'Fuel offloading risk assessment', 'Construction phase plan risk review',
                'Laboratory biological risk assessment', 'Night shift operations HIRA',
                'Maintenance workshop JSA', 'Emergency response preparedness review',
            ]
            for n, title in enumerate(ra_titles):
                site = sites[n % len(sites)]
                assessment = RiskAssessment.objects.create(
                    title=title, site=site,
                    scope=f'All activities performed at {site.name} under normal, abnormal and emergency conditions.',
                    methodology=rng.choice(['5x5', 'hira', 'jsa', 'hazop', 'fmea']),
                    status=rng.choices(
                        ['approved', 'in_review', 'draft', 'expired'],
                        weights=[55, 20, 15, 10],
                    )[0],
                    assessor_name=person(rng),
                    assessment_date=today - timedelta(days=rng.randint(20, 420)),
                    review_date=today + timedelta(days=rng.randint(-45, 330)),
                    approved_by=person(rng) if rng.random() > 0.3 else '',
                    approved_at=timezone.now() - timedelta(days=rng.randint(5, 300))
                    if rng.random() > 0.3 else None,
                    summary='Assessment reviewed with the site safety committee; controls agreed and assigned.',
                )
                for i in range(rng.randint(5, 10)):
                    sev = rng.randint(1, 5)
                    lik = rng.randint(1, 5)
                    RiskAssessmentItem.objects.create(
                        assessment=assessment,
                        hazard_text=rng.choice([
                            'Contact with moving machinery parts',
                            'Fall from height during racking maintenance',
                            'Exposure to organic solvent vapour',
                            'Struck by reversing forklift',
                            'Manual handling of 25 kg bags',
                            'Slip on wet production floor',
                            'Electrical shock during maintenance',
                            'Dust inhalation during offloading',
                            'Entrapment in confined space',
                        ]),
                        activity=rng.choice(['Normal operation', 'Maintenance', 'Start-up', 'Emergency', 'Cleaning']),
                        consequence=rng.choice(['Minor injury', 'Lost time injury', 'Serious injury', 'Fatality', 'Property damage']),
                        existing_controls='Guard rails, signage, PPE, induction training.',
                        additional_controls='Engineering upgrade, revised SOP, refresher training.',
                        severity=sev, likelihood=lik,
                        residual_severity=max(1, sev - 1), residual_likelihood=max(1, lik - 1),
                        responsible=person(rng),
                        due_date=today + timedelta(days=rng.randint(-30, 150)),
                        status=rng.choices(['open', 'in_progress', 'closed'], weights=[40, 35, 25])[0],
                        sort_order=i,
                    )
            self.stdout.write(f'  risk assessments: {RiskAssessment.objects.count()}')

        # ── Incidents + CAPA ─────────────────────────────────────────────
        if _want('incidents'):
            incident_titles = [
                ('Hand laceration while clearing jam', 'injury', 'moderate'),
                ('Forklift clipped racking upright', 'property_damage', 'minor'),
                ('Near miss: falling pallet in aisle 4', 'near_miss', 'first_aid'),
                ('Solvent splash to forearm', 'injury', 'minor'),
                ('Slip on wet floor — ankle sprain', 'injury', 'moderate'),
                ('Chemical drum leak in store', 'environmental', 'moderate'),
                ('Electrical arc flash during panel work', 'injury', 'major'),
                ('Fall from ladder at mezzanine', 'injury', 'major'),
                ('Employee collapsed from heat stress', 'illness', 'moderate'),
                ('Vehicle reversing collision at gate', 'vehicle', 'minor'),
                ('Fire in waste paper bin', 'fire', 'minor'),
                ('Needlestick injury in laboratory', 'injury', 'moderate'),
                ('Unauthorised entry into confined space', 'near_miss', 'first_aid'),
                ('Eye injury from grinding sparks', 'injury', 'minor'),
                ('Occupational asthma diagnosis', 'illness', 'moderate'),
                ('Fatal fall from scaffold level 3', 'injury', 'fatality'),
            ]
            for n, (title, itype, sev) in enumerate(incident_titles):
                occurred = timezone.now() - timedelta(days=rng.randint(1, 400), hours=rng.randint(0, 23))
                site = sites[n % len(sites)]
                is_lti = sev in ('moderate', 'major', 'fatality') and rng.random() > 0.35
                lost = rng.randint(1, 45) if is_lti else 0
                incident = Incident.objects.create(
                    title=title, incident_type=itype, severity=sev, site=site,
                    location=rng.choice(['Aisle 3', 'Production line 2', 'Chemical store', 'Gate 1',
                                         'Maintenance workshop', 'Laboratory bench 4', 'Mezzanine']),
                    department=rng.choice(['Operations', 'Warehousing', 'Maintenance', 'Laboratory', 'Transport', 'Production']),
                    occurred_at=occurred,
                    reported_at=occurred + timedelta(hours=rng.randint(0, 6)),
                    person_involved=person(rng),
                    person_role=rng.choice(['Operator', 'Forklift driver', 'Technician', 'Lab analyst',
                                            'Contractor', 'Driver', 'Supervisor']),
                    description=f'{title}. Reported through the OHS incident hotline and logged for investigation.',
                    immediate_action=rng.choice([
                        'Area isolated and made safe; first aid administered.',
                        'Machine stopped and LOTO applied; area barricaded.',
                        'Spill kit deployed and absorbent applied; waste drummed.',
                        'Casualty evacuated to company clinic; scene preserved.',
                        'Vehicle movements suspended pending assessment.',
                    ]),
                    root_cause=rng.choice([
                        'Guarding interlock bypassed to reduce cycle time.',
                        'Procedure did not cover the abnormal start-up condition.',
                        'Housekeeping not completed before shift handover.',
                        'PPE not worn because of heat discomfort.',
                        'Pre-use inspection skipped under schedule pressure.',
                        'Traffic management plan not followed by contractor.',
                    ]),
                    cause_category=rng.choice(causes),
                    is_recordable=sev in ('moderate', 'major', 'fatality'),
                    is_lost_time=is_lti, lost_days=lost,
                    days_away=max(0, lost - rng.randint(0, 2)) if is_lti else 0,
                    cost_estimate=Decimal(rng.randint(5000, 900000)),
                    status=rng.choices(
                        ['reported', 'investigating', 'actions', 'closed'],
                        weights=[10, 20, 30, 40],
                    )[0],
                    reported_by=person(rng),
                    investigator=person(rng) if sev != 'first_aid' else '',
                    regulator_notified=sev in ('major', 'fatality'),
                    witness_statements='Statement collected from the injured person and two witnesses.'
                    if sev in ('major', 'fatality') else '',
                )
                if incident.status == 'closed':
                    incident.closed_at = occurred + timedelta(days=rng.randint(5, 60))
                    incident.save(update_fields=['closed_at'])
                for k in range(rng.randint(1, 4)):
                    due = today + timedelta(days=rng.randint(-120, 90))
                    st = rng.choices(
                        ['open', 'in_progress', 'done', 'verified'],
                        weights=[20, 25, 30, 25],
                    )[0]
                    IncidentAction.objects.create(
                        incident=incident,
                        action_type=rng.choice(['containment', 'corrective', 'preventive', 'training', 'engineering']),
                        description=rng.choice([
                            'Fit interlocked guard and remove bypass switch.',
                            'Revise SOP and re-brief all operators.',
                            'Deliver refresher manual-handling training.',
                            'Install additional task lighting in the aisle.',
                            'Add spotter requirement to traffic management plan.',
                            'Replace damaged ladder and quarantine remainder.',
                            'Increase housekeeping audit frequency to daily.',
                            'Install local exhaust ventilation at the decanting point.',
                        ]),
                        owner_name=person(rng), due_date=due, status=st,
                        completed_at=due - timedelta(days=rng.randint(0, 5))
                        if st in ('done', 'verified') else None,
                        verification_note='Effectiveness verified during follow-up walkdown.'
                        if st == 'verified' else '',
                    )
            self.stdout.write(f'  incidents: {Incident.objects.count()} ({IncidentAction.objects.count()} CAPA)')

        # ── Inspections ──────────────────────────────────────────────────
        if _want('inspections'):
            checklists = [
                ('Machine guarding in place and interlocked', 'Machine safety'),
                ('Emergency exits unobstructed', 'Fire safety'),
                ('Fire extinguishers serviced and tagged', 'Fire safety'),
                ('PPE worn as required', 'PPE'),
                ('Walkways clear and marked', 'Housekeeping'),
                ('Electrical panels closed and labelled', 'Electrical'),
                ('Chemical containers labelled and closed', 'Chemical'),
                ('Eye wash station accessible and in date', 'Chemical'),
                ('First aid kit complete', 'First aid'),
                ('Forklift pre-use checks recorded', 'Vehicles'),
                ('Ladders inspected and tagged', 'Work at height'),
                ('Noise signage displayed in high-noise areas', 'Occupational health'),
            ]
            for n in range(18):
                site = sites[n % len(sites)]
                scheduled = today - timedelta(days=rng.randint(-40, 120))
                done = scheduled < today and rng.random() > 0.25
                inspection = Inspection.objects.create(
                    title=f'{rng.choice(["Routine", "Planned", "Statutory", "Spot"])} inspection — {site.name}',
                    inspection_type=rng.choice(['routine', 'planned', 'statutory', 'surprise']),
                    site=site,
                    area=rng.choice(['Warehouse floor', 'Production hall', 'Chemical store',
                                     'Vehicle yard', 'Laboratory', 'Office block']),
                    inspector_name=person(rng),
                    scheduled_for=scheduled,
                    completed_on=scheduled if done else None,
                    status='completed' if done else ('overdue' if scheduled < today else 'scheduled'),
                    score=rng.randint(62, 98) if done else None,
                    summary='Findings reviewed with the area supervisor; corrective actions logged.'
                    if done else '',
                )
                for i, (text, cat) in enumerate(checklists):
                    res = rng.choices(
                        ['pass', 'fail', 'observation', 'na'], weights=[70, 12, 13, 5],
                    )[0] if done else 'pass'
                    InspectionItem.objects.create(
                        inspection=inspection, checklist_item=text, category=cat,
                        result=res,
                        severity=rng.choices(['low', 'medium', 'high', 'critical'],
                                             weights=[50, 30, 15, 5])[0],
                        notes='' if res == 'pass' else 'Gap observed during walkdown; action assigned.',
                        corrective_action='' if res == 'pass' else 'Rectify within 7 days and evidence in register.',
                        sort_order=i,
                    )
            self.stdout.write(f'  inspections: {Inspection.objects.count()}')

        # ── Permits ──────────────────────────────────────────────────────
        if _want('permits'):
            permit_titles = [
                'Hot work — welding on conveyor frame',
                'Confined space entry — tank 3 internal clean',
                'Work at height — racking repair level 2',
                'Electrical isolation — main switchboard maintenance',
                'Excavation — drainage trench Block C',
                'Lifting operation — 12 t generator relocation',
                'Chemical transfer — solvent decanting',
                'General maintenance — compressor overhaul',
            ]
            for n, title in enumerate(permit_titles):
                site = sites[n % len(sites)]
                valid_from = timezone.now() - timedelta(hours=rng.randint(1, 240))
                valid_to = valid_from + timedelta(hours=rng.choice([8, 12, 24, 48, 72]))
                PermitToWork.objects.create(
                    permit_type=rng.choice([
                        'hot_work', 'confined_space', 'height', 'electrical',
                        'excavation', 'lifting', 'chemical', 'general',
                    ]),
                    title=title, site=site,
                    area=rng.choice(['Workshop', 'Tank farm', 'Racking level 2', 'Switch room', 'Block C', 'Yard']),
                    description=f'{title}. Controls agreed at the pre-job briefing.',
                    requested_by=person(rng), issued_by=person(rng),
                    approved_by=person(rng) if rng.random() > 0.2 else '',
                    valid_from=valid_from, valid_to=valid_to,
                    status=rng.choices(
                        ['active', 'approved', 'closed', 'pending', 'expired', 'suspended'],
                        weights=[25, 20, 30, 15, 7, 3],
                    )[0],
                    risk_level=rng.choice(['low', 'medium', 'high']),
                    precautions='Area barricaded; fire watch posted; gas test before entry; LOTO applied.',
                    ppe_required='Helmet, safety boots, goggles, gloves, hi-vis vest',
                    isolations='Electrical isolation tag 1124; valve V-203 locked closed'
                    if rng.random() > 0.4 else '',
                    gas_test_required=rng.random() > 0.5,
                    workers_count=rng.randint(2, 9),
                    closure_note='Work completed, area handed back and permit closed.'
                    if rng.random() > 0.6 else '',
                )
            self.stdout.write(f'  permits: {PermitToWork.objects.count()}')

        # ── Training ─────────────────────────────────────────────────────
        if _want('training'):
            course_specs = [
                ('OHS Induction', 'IND-01', 'induction', True, 12, 'Internal'),
                ('Fire Safety & Evacuation', 'FSE-01', 'emergency', True, 12, 'Kenya Red Cross'),
                ('First Aid at Work', 'FAW-01', 'emergency', True, 24, 'St John Ambulance'),
                ('Forklift Operator Certification', 'FLO-01', 'technical', True, 36, 'NTSA Approved'),
                ('Work at Height & Fall Protection', 'WAH-01', 'technical', True, 24, 'SafeWork Africa'),
                ('Confined Space Entry', 'CSE-01', 'technical', True, 24, 'SafeWork Africa'),
                ('Chemical Handling & SDS', 'CHM-01', 'technical', True, 24, 'Internal'),
                ('Hazard Identification & Risk Assessment', 'HIRA-01', 'technical', False, 36, 'Internal'),
                ('Incident Investigation (ICAM)', 'ICAM-01', 'technical', False, 36, 'SafeWork Africa'),
                ('Manual Handling', 'MH-01', 'technical', False, 12, 'Internal'),
                ('Permit to Work Issuer', 'PTW-01', 'legal', True, 24, 'Internal'),
                ('ISO 45001 Internal Auditor', 'ISO-AUD', 'legal', False, 36, 'Bureau Veritas'),
                ('Occupational Noise & Hearing Conservation', 'NSE-01', 'technical', False, 12, 'Internal'),
                ('Emergency Response Team Leader', 'ERT-01', 'emergency', False, 24, 'Kenya Red Cross'),
            ]
            courses = []
            for name, code, cat, mand, validity, provider in course_specs:
                course, _ = TrainingCourse.objects.get_or_create(
                    code=code,
                    defaults=dict(
                        name=name, category=cat, is_mandatory=mand,
                        validity_months=validity, provider=provider,
                        duration_hours=rng.choice([4, 6, 8, 16]),
                        cost_per_person=Decimal(rng.choice([1500, 2500, 4000, 6500, 12000])),
                        description=f'{name} covering the competencies required by the OHSMS.',
                    ),
                )
                courses.append(course)
            for emp, ref in people:
                for course in rng.sample(courses, rng.randint(2, 6)):
                    completed = today - timedelta(days=rng.randint(10, 800))
                    expires = (
                        completed + timedelta(days=course.validity_months * 30)
                        if course.validity_months else None
                    )
                    TrainingRecord.objects.create(
                        course=course, employee_name=emp, employee_ref=ref,
                        site=rng.choice(sites),
                        completed_on=completed, expires_on=expires,
                        result=rng.choices(['pass', 'fail', 'pending'], weights=[92, 5, 3])[0],
                        score=rng.randint(55, 100),
                        certificate_ref=f'CERT-{rng.randint(10000, 99999)}',
                        trainer=person(rng),
                    )
            self.stdout.write(f'  training: {TrainingCourse.objects.count()} courses / {TrainingRecord.objects.count()} records')

        # ── PPE ──────────────────────────────────────────────────────────
        if _want('ppe'):
            ppe_specs = [
                ('Safety helmet', 'head', 'EN 397', 240, 60),
                ('Safety goggles', 'eye', 'EN 166', 180, 60),
                ('Face shield', 'eye', 'EN 166', 45, 20),
                ('Ear defenders', 'hearing', 'EN 352', 90, 40),
                ('Disposable ear plugs', 'hearing', 'EN 352-2', 900, 300),
                ('N95 respirator', 'respiratory', 'EN 149', 420, 200),
                ('Full-face respirator', 'respiratory', 'EN 136', 18, 15),
                ('Leather gloves', 'hand', 'EN 388', 300, 120),
                ('Chemical gloves (nitrile)', 'hand', 'EN 374', 150, 80),
                ('Safety boots', 'foot', 'EN ISO 20345', 210, 80),
                ('Hi-vis vest', 'hi_vis', 'EN ISO 20471', 260, 90),
                ('Coverall', 'body', 'EN ISO 11612', 180, 70),
                ('Full body harness', 'fall', 'EN 361', 26, 15),
                ('Welding apron', 'body', 'EN ISO 11611', 12, 10),
            ]
            for name, cat, std, stock, reorder in ppe_specs:
                PpeItem.objects.get_or_create(
                    name=name,
                    defaults=dict(
                        category=cat, code=name[:6].upper().replace(' ', ''),
                        standard=std, stock_on_hand=stock, reorder_level=reorder,
                        unit='piece', unit_cost=Decimal(rng.choice([250, 600, 1200, 2500, 4800, 9500])),
                        replacement_months=rng.choice([6, 12, 18, 24]),
                        sizes='S,M,L,XL' if cat in ('body', 'foot', 'hi_vis') else '',
                    ),
                )
            for _ in range(120):
                issued = today - timedelta(days=rng.randint(1, 420))
                item = rng.choice(PpeItem.objects.all())
                PpeIssue.objects.create(
                    ppe_item=item, employee_name=person(rng), employee_ref=ref_person(rng),
                    site=rng.choice(sites), quantity=rng.randint(1, 3),
                    size=rng.choice(['M', 'L', 'XL', '10', '42', '']),
                    issued_on=issued,
                    replacement_due=issued + timedelta(days=item.replacement_months * 30),
                    condition=rng.choice(['new', 'good', 'serviceable']),
                    acknowledged=True,
                )
            self.stdout.write(f'  ppe: {PpeItem.objects.count()} items / {PpeIssue.objects.count()} issues')

        # ── Health surveillance ──────────────────────────────────────────
        if _want('health_surveillance'):
            for _ in range(70):
                sched = today - timedelta(days=rng.randint(-30, 300))
                done = sched < today and rng.random() > 0.25
                HealthSurveillance.objects.create(
                    programme=rng.choice(['audiometry', 'spirometry', 'vision', 'blood_lead',
                                          'hazmat', 'ergonomic', 'general']),
                    employee_name=person(rng), employee_ref=ref_person(rng),
                    job_title=rng.choice(['Operator', 'Forklift driver', 'Technician', 'Lab analyst',
                                          'Welder', 'Security', 'Supervisor']),
                    site=rng.choice(sites),
                    scheduled_on=sched,
                    completed_on=sched if done else None,
                    result=rng.choices(['fit', 'conditional', 'unfit', 'pending'],
                                       weights=[70, 15, 3, 12])[0] if done else 'pending',
                    restrictions='Avoid sustained noise exposure above 85 dB(A); re-test in 6 months.'
                    if done and rng.random() > 0.6 else '',
                    provider=rng.choice(['Company clinic', 'AAR Occupational Health', 'Minet', 'Nairobi Occupational Health']),
                    next_due=sched + timedelta(days=365) if done else None,
                    notes='Annual surveillance per the OHSMS health programme.'
                    if done and rng.random() > 0.5 else '',
                )
            self.stdout.write(f'  health surveillance: {HealthSurveillance.objects.count()}')

        # ── Exposure monitoring ──────────────────────────────────────────
        if _want('exposure'):
            agent_spec = {
                'noise': ('dB(A)', 85, 78, 104),
                'dust': ('mg/m³', 5, 0.8, 8.5),
                'vapour': ('ppm', 50, 4, 78),
                'heat': ('WBGT °C', 30, 22, 36),
                'vibration': ('m/s²', 5, 1.5, 7.2),
                'radiation': ('µSv/h', 7.5, 0.4, 9.1),
                'lighting': ('lux', 500, 180, 780),
                'ergonomic': ('REBA score', 8, 2, 11),
            }
            for agent, (unit, limit, lo, hi) in agent_spec.items():
                for _ in range(rng.randint(3, 8)):
                    value = round(rng.uniform(lo, hi), 2)
                    pct = value / limit
                    ExposureMonitoring.objects.create(
                        agent=agent, site=rng.choice(sites),
                        area=rng.choice(['Milling section', 'Compressor room', 'Paint shop',
                                         'Fabrication shop', 'Warehouse floor', 'Night access route']),
                        measured_value=Decimal(str(value)), unit=unit, oel_limit=Decimal(str(limit)),
                        measured_on=today - timedelta(days=rng.randint(5, 340)),
                        method=rng.choice(['Personal sampling', 'Area sampling', 'Direct reading instrument']),
                        result='exceeded' if pct >= 1 else ('action' if pct >= 0.8 else 'compliant'),
                        lab_reference=f'LAB-{rng.randint(10000, 99999)}',
                    )
            self.stdout.write(f'  exposure readings: {ExposureMonitoring.objects.count()}')

        # ── Observations ─────────────────────────────────────────────────
        if _want('observations'):
            for _ in range(180):
                Observation.objects.create(
                    site=rng.choice(sites), observer_name=person(rng),
                    observed_person=person(rng) if rng.random() > 0.2 else '',
                    department=rng.choice(['Operations', 'Warehousing', 'Maintenance', 'Laboratory', 'Transport']),
                    kind=rng.choices(['safe', 'at_risk', 'condition', 'positive'],
                                     weights=[40, 30, 22, 8])[0],
                    category=rng.choice(['ppe', 'position', 'tools', 'procedure', 'housekeeping',
                                         'lifting', 'driving', 'chemical']),
                    description=rng.choice([
                        'Observed correct use of full PPE during task.',
                        'Operator reached over moving conveyor instead of using the walkway.',
                        'Tools left on elevated platform above head height.',
                        'Lock-out tag applied correctly before maintenance.',
                        'Good housekeeping after shift handover.',
                        'Manual lifting of 25 kg bag without a colleague.',
                        'Forklift speed in aisle above the 10 km/h limit.',
                        'Secondary containment in place for solvent drums.',
                    ]),
                    feedback_given=rng.random() > 0.15,
                    action_taken='Coaching conversation held and correction agreed on the spot.'
                    if rng.random() > 0.4 else '',
                    observed_at=timezone.now() - timedelta(days=rng.randint(0, 240)),
                )
            self.stdout.write(f'  observations: {Observation.objects.count()}')

        # ── Emergency drills ─────────────────────────────────────────────
        if _want('drills'):
            for _ in range(14):
                sched = today - timedelta(days=rng.randint(-60, 330))
                done = sched < today and rng.random() > 0.2
                EmergencyDrill.objects.create(
                    drill_type=rng.choice(['fire', 'chemical', 'medical', 'earthquake',
                                           'confined_space', 'security', 'power']),
                    site=rng.choice(sites), scheduled_on=sched,
                    conducted_on=sched if done else None,
                    status='completed' if done else ('planned' if sched >= today else 'cancelled'),
                    participants=rng.randint(20, 220) if done else 0,
                    duration_minutes=rng.randint(15, 60) if done else 0,
                    evacuation_seconds=rng.randint(95, 420) if done else None,
                    scenario='Simulated evacuation with casualty extraction to the assembly point.',
                    findings='Assembly roll call took longer than target; marshal roles to be re-briefed.'
                    if done else '',
                    score=rng.randint(60, 95) if done else None,
                    coordinator=person(rng),
                )
            self.stdout.write(f'  drills: {EmergencyDrill.objects.count()}')

        # ── Legal register ───────────────────────────────────────────────
        if _want('legal_register'):
            legal_specs = [
                ('OSHA 2007', 's.6', 'Duty of employer to ensure safety, health and welfare at work'),
                ('OSHA 2007', 's.7', 'Safety and health policy statement and its communication'),
                ('OSHA 2007', 's.9', 'Establishment of a safety and health committee'),
                ('OSHA 2007', 's.10', 'Notification and investigation of accidents and dangerous occurrences'),
                ('OSHA 2007', 's.11', 'Pre-employment and annual medical examinations'),
                ('OSHA 2007', 's.12', 'Provision and maintenance of personal protective equipment'),
                ('OSHA 2007', 's.13', 'Prohibition of smoking, alcohol and drugs at the workplace'),
                ('OSHA 2007', 's.14', 'Fire safety and means of escape'),
                ('OSHA 2007', 's.16', 'Handling, storage and transport of hazardous substances'),
                ('Factories Act Cap 514', 's.22', 'Fencing of machinery and safe working parts'),
                ('Factories Act Cap 514', 's.27', 'Lifting machines, chains, ropes and tackles'),
                ('Factories Act Cap 514', 's.29', 'Steam boilers — examinations and reports'),
                ('Factories Act Cap 514', 's.48', 'Removal of dust and fumes'),
                ('WIBA 2007', 's.7', 'Employer contributions to injury benefit'),
                ('WIBA 2007', 's.21', 'Reporting of occupational injuries and diseases'),
                ('EMCA 1999', 's.9', 'Environmental impact assessment for new projects'),
                ('EMCA 1999', 's.13', 'Discharge of pollutants to the environment'),
                ('Energy Act 2019', 's.60', 'Petroleum product storage and dispensing licence'),
                ('NEMA Regulations', 'Sch.1', 'Waste segregation and licensed disposal'),
                ('ISO 45001:2018', '4.1', 'Understanding the organisation and its context'),
                ('ISO 45001:2018', '5.2', 'OH&S policy'),
                ('ISO 45001:2018', '6.1.2', 'Hazard identification and assessment of risks'),
                ('ISO 45001:2018', '7.2', 'Competence of workers'),
                ('ISO 45001:2018', '8.1.2', 'Eliminating hazards and reducing OH&S risks'),
                ('ISO 45001:2018', '9.1', 'Monitoring, measurement, analysis and performance evaluation'),
                ('ISO 45001:2018', '10.2', 'Incident, nonconformity and corrective action'),
            ]
            for standard, clause, title in legal_specs:
                st = rng.choices(
                    ['compliant', 'partial', 'non_compliant', 'not_assessed'],
                    weights=[55, 25, 10, 10],
                )[0]
                last = today - timedelta(days=rng.randint(20, 400))
                LegalRequirement.objects.create(
                    standard=standard, clause=clause, title=title,
                    description=f'Obligation arising from {standard} {clause}.',
                    applies_to=rng.choice(['All sites', 'High-hazard sites', 'Laboratory', 'Warehouse', 'Fuel terminal']),
                    compliance_status=st, owner_name=person(rng),
                    last_assessed_on=last if st != 'not_assessed' else None,
                    next_review_on=last + timedelta(days=365) if st != 'not_assessed' else None,
                    evidence='Compliance evidence filed in the OHSMS document control folder.'
                    if st in ('compliant', 'partial') else '',
                    gap_description='Gap recorded; corrective action tracked in the compliance plan.'
                    if st in ('partial', 'non_compliant') else '',
                )
            self.stdout.write(f'  legal requirements: {LegalRequirement.objects.count()}')

        # ── Audits ───────────────────────────────────────────────────────
        if _want('audits'):
            audit_titles = [
                'ISO 45001 stage 2 certification audit',
                'Internal OHSMS audit — operations',
                'Contractor management audit',
                'Chemical store statutory audit',
                'Annual management system review audit',
                'Supplier OHS prequalification audit',
            ]
            for title in audit_titles:
                sched = today - timedelta(days=rng.randint(-40, 320))
                done = sched < today and rng.random() > 0.2
                ComplianceAudit.objects.create(
                    title=title,
                    audit_type=rng.choice(['internal', 'external', 'certification', 'supplier']),
                    standard=rng.choice(['ISO 45001:2018', 'OSHA 2007', 'ISO 14001', 'Internal']),
                    site=rng.choice(sites), scope='Site operations, contractor control and document control.',
                    auditor=rng.choice(['Bureau Veritas', 'SGS Kenya', 'Internal audit team', 'SafeWork Africa']),
                    scheduled_on=sched, completed_on=sched if done else None,
                    status='completed' if done else 'planned',
                    score=rng.randint(64, 96) if done else None,
                    findings_major=rng.randint(0, 3) if done else 0,
                    findings_minor=rng.randint(2, 14) if done else 0,
                    summary='Findings agreed with management; corrective action plan issued.'
                    if done else '',
                )
            self.stdout.write(f'  audits: {ComplianceAudit.objects.count()}')

        # ── Objectives ───────────────────────────────────────────────────
        if _want('objectives'):
            objective_specs = [
                ('Reduce recordable incidents by 25%', 'incident_reduction', 34, 25.5, 30, 'incidents / yr'),
                ('Achieve 95% mandatory training compliance', 'training', 78, 95, 88.4, '%'),
                ('Close 90% of CAPA within due date', 'compliance', 64, 90, 71.2, '%'),
                ('Eliminate high-risk hazards below 10 open', 'risk', 26, 10, 17, 'hazards'),
                ('Achieve 80% safe behaviour observations', 'culture', 58, 80, 67.5, '%'),
                ('Complete 100% statutory health surveillance', 'health', 62, 100, 81, '%'),
            ]
            for title, cat, base, target, current, unit in objective_specs:
                SafetyObjective.objects.create(
                    title=title, category=cat,
                    site=rng.choice([None, *sites]),
                    baseline_value=Decimal(str(base)), target_value=Decimal(str(target)),
                    current_value=Decimal(str(current)), unit=unit,
                    owner_name=person(rng),
                    start_date=today - timedelta(days=rng.randint(60, 300)),
                    due_date=today + timedelta(days=rng.randint(30, 240)),
                    status=rng.choice(['on_track', 'at_risk', 'off_track']),
                    description=f'Annual OH&S objective approved at management review.',
                    actions_plan='Monthly progress review at the safety committee.',
                )
            self.stdout.write(f'  objectives: {SafetyObjective.objects.count()}')

        # ── Document control & SDS library ───────────────────────────────
        if _want('documents'):
            doc_specs = [
                ('OH&S Policy', 'policy', 'approved', False, 'Signed by the CEO; reviewed annually.'),
                ('Hazard Identification & Risk Assessment Procedure', 'procedure', 'approved', True,
                 'Defines the 5×5 methodology, HIRA triggers and re-assessment cadence.'),
                ('Incident Reporting & Investigation Procedure', 'procedure', 'approved', True,
                 'ICAM-based investigation, 24-hour reporting window.'),
                ('Permit to Work Procedure', 'procedure', 'approved', True,
                 'Authorisation matrix for hot work, confined space and height.'),
                ('PPE Issue & Maintenance Procedure', 'procedure', 'approved', True,
                 'Issue register, inspection frequency and replacement criteria.'),
                ('Emergency Preparedness & Response Plan', 'emergency_plan', 'approved', True,
                 'Muster points, wardens, evacuation routes and drill schedule.'),
                ('Contractor Management Procedure', 'procedure', 'in_review', True,
                 'Pre-qualification, induction and site supervision requirements.'),
                ('Forklift Safe Operating Procedure', 'work_instruction', 'approved', True,
                 'Pre-use checks, speed limits and pedestrian segregation.'),
                ('Confined Space Entry Work Instruction', 'work_instruction', 'approved', True,
                 'Gas testing, rescue plan and attendant duties.'),
                ('Manual Handling Work Instruction', 'work_instruction', 'approved', False,
                 'Team lifting above 20 kg and mechanical aids.'),
                ('Hazardous Waste Disposal Procedure', 'procedure', 'approved', False,
                 'Segregation, licensed carrier and manifest retention.'),
                ('Management of Change Procedure', 'procedure', 'draft', False,
                 'Assessment of safety impacts before plant or process changes.'),
                ('OH&S Induction Handbook', 'manual', 'approved', True,
                 'Site rules, emergency arrangements and reporting duties.'),
                ('Chemical Inventory & SDS Index', 'form', 'approved', False,
                 'Master list linking each chemical to its current safety data sheet.'),
                ('Toolbox Talk Record Form', 'form', 'approved', False,
                 'Attendance and topics for weekly briefings.'),
                ('Occupational Health Surveillance Procedure', 'procedure', 'approved', True,
                 'Medical frequency by exposure group and fitness outcomes.'),
                ('Acetylene (dissolved) — Safety Data Sheet', 'sds', 'approved', True,
                 'Highly flammable gas; store upright in ventilated cage.'),
                ('Sodium Hydroxide 50% Solution — Safety Data Sheet', 'sds', 'approved', True,
                 'Corrosive; causes severe burns. PPE: face shield, nitrile gloves.'),
                ('Isopropyl Alcohol 99% — Safety Data Sheet', 'sds', 'approved', True,
                 'Highly flammable liquid and vapour; keep away from ignition sources.'),
                ('Diesel Fuel — Safety Data Sheet', 'sds', 'approved', True,
                 'Flammable liquid; skin irritant. Bunded storage required.'),
                ('Hydrogen Peroxide 35% — Safety Data Sheet', 'sds', 'approved', True,
                 'Oxidiser; corrosive. Segregate from combustibles.'),
                ('Cement (Portland) — Safety Data Sheet', 'sds', 'approved', False,
                 'Respiratory sensitiser; silica dust hazard. Use RPE and extraction.'),
                ('Chlorine Tablets — Safety Data Sheet', 'sds', 'in_review', False,
                 'Toxic gas on contact with acid; store locked and segregated.'),
                ('Lubricating Oil — Safety Data Sheet', 'sds', 'approved', False,
                 'Low hazard; avoid prolonged skin contact.'),
            ]
            for title, dtype, status, ack, summary in doc_specs:
                site = rng.choice([None, *sites])
                doc = Document.objects.create(
                    title=title, doc_type=dtype, status=status,
                    classification='internal' if dtype != 'sds' else 'public',
                    site=site,
                    version=f'{rng.randint(1, 4)}.{rng.randint(0, 3)}',
                    owner_name=person(rng), summary=summary,
                    effective_date=today - timedelta(days=rng.randint(30, 600)),
                    review_due=today + timedelta(days=rng.randint(-90, 330)),
                    requires_acknowledgement=ack,
                    approved_by=person(rng) if status == 'approved' else '',
                    approved_at=timezone.now() - timedelta(days=rng.randint(10, 400))
                    if status == 'approved' else None,
                    chemical_name=title.split(' — ')[0] if dtype == 'sds' else '',
                    hazard_class=rng.choice([
                        'Flammable liquid', 'Corrosive', 'Oxidiser', 'Toxic',
                        'Health hazard', 'Irritant', '',
                    ]) if dtype == 'sds' else '',
                    tags=','.join(rng.sample(
                        ['ohs', 'statutory', 'iso45001', 'chemical', 'site-rules', 'emergency'],
                        rng.randint(1, 3),
                    )),
                )
                for rev in range(rng.randint(1, 3)):
                    DocumentRevision.objects.create(
                        document=doc, version=f'{rev + 1}.0',
                        change_summary=rng.choice([
                            'Annual review — no material changes.',
                            'Updated responsibilities following reorganisation.',
                            'Added confined space rescue requirements.',
                            'Aligned with revised statutory guidance.',
                            'Corrected PPE specification and issue frequency.',
                        ]),
                        revised_by=person(rng),
                        revised_on=today - timedelta(days=rng.randint(30, 700)),
                        approved_by=person(rng),
                    )
                doc.revision_count = doc.revisions.count()
                doc.save(update_fields=['revision_count'])
                if ack:
                    for emp, ref in rng.sample(people, rng.randint(6, 22)):
                        DocumentAcknowledgement.objects.create(
                            document=doc, employee_name=emp, employee_ref=ref,
                            site=site, acknowledged_on=today - timedelta(days=rng.randint(1, 200)),
                            version_read=doc.version,
                        )
            self.stdout.write(
                f'  documents: {Document.objects.count()} '
                f'({Document.objects.filter(doc_type="sds").count()} SDS, '
                f'{DocumentAcknowledgement.objects.count()} acknowledgements)'
            )

        # ── Contractors ──────────────────────────────────────────────────
        if _want('contractors'):
            contractor_specs = [
                ('Safaricom Towers Electrical Ltd', 'electrical', 'approved', 'high'),
                ('Kenya Civil Works Ltd', 'civil', 'approved', 'high'),
                ('HighRise Scaffolding Co.', 'scaffolding', 'approved', 'high'),
                ('CleanPro Facility Services', 'cleaning', 'approved', 'low'),
                ('Rift Valley Logistics', 'logistics', 'approved', 'medium'),
                ('Mechanical Solutions EA', 'mechanical', 'approved', 'medium'),
                ('Guardian Security Services', 'security', 'approved', 'low'),
                ('Bytes & Networks IT', 'it', 'approved', 'low'),
                ('Summit Catering Ltd', 'catering', 'pending', 'low'),
                ('QuickFix Maintenance', 'mechanical', 'suspended', 'high'),
                ('Eastland Fabricators', 'mechanical', 'expired', 'high'),
                ('Prime Waste Handlers', 'cleaning', 'approved', 'medium'),
            ]
            for name, trade, status, risk in contractor_specs:
                offset_ins = rng.choice([-45, -10, 25, 120, 240, 400])
                offset_sf = rng.choice([-30, 15, 60, 180, 330])
                offset_ind = rng.choice([-20, 40, 90, 200, 365])
                offset_lic = rng.choice([-60, 30, 100, 260])
                Contractor.objects.get_or_create(
                    name=name,
                    defaults=dict(
                        registration_no=f'CPR/{rng.randint(2000, 2024)}/{rng.randint(100, 999)}',
                        trade=trade, status=status, risk_rating=risk,
                        contact_person=person(rng),
                        phone=f'+2547{rng.randint(10000000, 99999999)}',
                        email=f'info@{name.split()[0].lower()}.co.ke',
                        prequalified_on=today - timedelta(days=rng.randint(60, 700)),
                        insurance_expiry=today + timedelta(days=offset_ins),
                        safety_file_expiry=today + timedelta(days=offset_sf),
                        induction_valid_until=today + timedelta(days=offset_ind),
                        licence_expiry=today + timedelta(days=offset_lic),
                        performance_score=rng.randint(58, 96),
                        incidents_attributed=rng.randint(0, 3),
                        observations_logged=rng.randint(2, 30),
                        workers_count=rng.randint(4, 60),
                        notes=rng.choice([
                            'Regular performer; strong supervision on site.',
                            'Improvement notice issued for housekeeping.',
                            'Requires escort at all times in chemical areas.',
                            'Preferred supplier for electrical works.',
                            '',
                        ]),
                    ),
                )
            contractors = list(Contractor.objects.all())
            for _ in range(18):
                start = today - timedelta(days=rng.randint(10, 300))
                ContractorEngagement.objects.create(
                    contractor=rng.choice(contractors), site=rng.choice(sites),
                    scope=rng.choice([
                        'Switchboard upgrade', 'Racking installation', 'Roof repairs',
                        'Deep cleaning contract', 'Machinery servicing', 'Waste removal',
                        'Security guarding', 'Network cabling', 'Canteen services',
                    ]),
                    supervisor_name=person(rng), start_date=start,
                    end_date=start + timedelta(days=rng.randint(14, 180)),
                    workers_on_site=rng.randint(2, 25),
                    hours_worked=rng.randint(80, 4000),
                    induction_completed=rng.random() > 0.15,
                    permit_required=rng.random() > 0.5,
                    ppe_provided=rng.random() > 0.2,
                    status=rng.choices(['planned', 'active', 'completed'], weights=[20, 40, 40])[0],
                )
            self.stdout.write(
                f'  contractors: {Contractor.objects.count()} '
                f'({ContractorEngagement.objects.count()} engagements)'
            )

        # ── Safety meetings / toolbox talks ──────────────────────────────
        if _want('meetings'):
            topics = [
                'Manual handling refresher', 'PPE compliance', 'Forklift pedestrian segregation',
                'Chemical spill response', 'Lock-out tag-out', 'Slips, trips and falls',
                'Emergency evacuation routes', 'Working at height', 'Hand tool safety',
                'Heat stress awareness', 'Near-miss reporting', 'Housekeeping standard',
            ]
            for _ in range(46):
                mtype = rng.choices(
                    ['committee', 'toolbox', 'induction', 'pre_job'],
                    weights=[12, 55, 18, 15],
                )[0]
                sched = today - timedelta(days=rng.randint(-20, 330))
                status = 'completed' if sched < today and rng.random() > 0.2 else 'scheduled'
                meeting = SafetyMeeting.objects.create(
                    title=(
                        f'Monthly Safety Committee — {sched.strftime("%B %Y")}'
                        if mtype == 'committee' else
                        f'Site induction — {rng.choice(topics)}'
                        if mtype == 'induction' else
                        f'Toolbox talk — {rng.choice(topics)}'
                    ),
                    meeting_type=mtype, site=rng.choice(sites),
                    meeting_date=sched,
                    start_time=f'{rng.randint(7, 16):02d}:{rng.choice([0, 15, 30, 45]):02d}',
                    duration_minutes=rng.choice([15, 20, 30, 45, 60, 90]),
                    chairperson=person(rng),
                    location=rng.choice(['Canteen', 'Training room', 'Assembly point',
                                          'Production hall', 'Site office']),
                    agenda=rng.choice(topics),
                    topics_covered=', '.join(rng.sample(topics, rng.randint(1, 3))),
                    minutes='Discussed current risk profile, reviewed near misses and agreed actions.'
                    if status == 'completed' else '',
                    decisions='Actions assigned and tracked in the CAPA register.'
                    if status == 'completed' else '',
                    status=status,
                    next_meeting_on=sched + timedelta(days=30) if mtype == 'committee' else None,
                )
                attendees = rng.sample(people, rng.randint(6, 24))
                for emp, ref in attendees:
                    MeetingAttendance.objects.create(
                        meeting=meeting, employee_name=emp, employee_ref=ref,
                        role=rng.choice(['Operator', 'Technician', 'Supervisor', 'Contractor', 'Admin']),
                        present=rng.random() > 0.08,
                        signed=rng.random() > 0.2,
                    )
                meeting.attendees_count = meeting.attendance.count()
                meeting.save(update_fields=['attendees_count'])
            self.stdout.write(
                f'  meetings: {SafetyMeeting.objects.count()} '
                f'({MeetingAttendance.objects.count()} attendance rows)'
            )

        # ── Management reviews ───────────────────────────────────────────
        if _want('management_reviews'):
            for i in range(4):
                rdate = today - timedelta(days=30 + i * 100)
                ManagementReview.objects.create(
                    title=f'Management review — {rdate.strftime("%B %Y")}',
                    review_date=rdate,
                    period_from=rdate - timedelta(days=365),
                    period_to=rdate,
                    chairperson=person(rng),
                    participants=', '.join(person(rng) for _ in range(5)),
                    agenda=(
                        '1. Status of actions from previous review\n'
                        '2. Changes in context, legal and other requirements\n'
                        '3. OH&S performance (lagging + leading indicators)\n'
                        '4. Adequacy of resources\n'
                        '5. Effectiveness of controls and consultation\n'
                        '6. Opportunities for improvement'
                    ),
                    inputs='Clause 9.3.2 inputs: incident trends, audit results, compliance, '
                           'objectives, worker consultation, resource adequacy.',
                    outputs='Clause 9.3.3 outputs: updated objectives, resource commitments, '
                            'priority actions and improvement plan.',
                    decisions=rng.choice([
                        'Approve capital for machine guarding upgrades.',
                        'Increase toolbox talk frequency to weekly across all sites.',
                        'Fund external ISO 45001 surveillance audit.',
                        'Approve additional occupational health nurse for the plant.',
                    ]),
                    status='completed' if i else 'scheduled',
                    outcome=rng.choice(['effective', 'improvement']) if i else '',
                    next_review_on=rdate + timedelta(days=365),
                    kpi_snapshot={
                        'trir': round(rng.uniform(0.2, 2.4), 2),
                        'ltifr': round(rng.uniform(0.4, 3.1), 2),
                        'open_hazards': rng.randint(12, 34),
                        'training_pct': round(rng.uniform(68, 96), 1),
                        'legal_pct': round(rng.uniform(70, 98), 1),
                    },
                )
            self.stdout.write(f'  management reviews: {ManagementReview.objects.count()}')

        # ── Certifications & licences ────────────────────────────────────
        if _want('certifications'):
            cert_specs = [
                ('ISO 45001:2018 Certification', 'iso', 'Bureau Veritas', 365),
                ('ISO 14001:2015 Certification', 'iso', 'Bureau Veritas', 365),
                ('Fire Safety Certificate', 'statutory', 'Nairobi County Fire Brigade', 300),
                ('OSHA Compliance Certificate', 'statutory', 'Directorate of Occupational Safety', 210),
                ('NEMA EIA Licence', 'license', 'NEMA Kenya', 420),
                ('Petroleum Storage & Dispensing Licence', 'license', 'Energy & Petroleum Regulatory Authority', 40),
                ('Public Health Certificate', 'statutory', 'Ministry of Health', 180),
                ('Boiler Inspection Certificate', 'equipment', 'Directorate of Occupational Safety', 25),
                ('Pressure Vessel Inspection', 'equipment', 'KEBS', 90),
                ('Lifting Equipment Examination', 'equipment', 'SGS Kenya', 15),
                ('Electrical Installation Certificate', 'equipment', 'EPRA licensed contractor', 320),
                ('Forklift Operator Certifications (12)', 'personnel', 'NTSA Approved Centre', 240),
                ('First Aid at Work Certifications (24)', 'personnel', 'St John Ambulance', 60),
                ('WIBA Group Personal Accident Cover', 'insurance', 'APA Insurance', 150),
                ('Public Liability Insurance', 'insurance', 'Jubilee Health', 150),
                ('Employer Liability Cover', 'insurance', 'Britam', -12),
                ('NCA Contractor Registration', 'license', 'National Construction Authority', 260),
                ('KEBS Product Certification', 'statutory', 'KEBS', 500),
            ]
            for name, ctype, body, offset in cert_specs:
                expires = today + timedelta(days=offset)
                if offset < 0:
                    status = 'expired'
                elif offset <= 60:
                    status = 'expiring'
                else:
                    status = 'active'
                Certification.objects.create(
                    name=name, cert_type=ctype,
                    reference_no=f'{ctype[:3].upper()}-{rng.randint(10000, 99999)}',
                    issuing_body=body, holder_name=rng.choice([s.name for s in sites]),
                    site=rng.choice([None, *sites]),
                    issued_on=expires - timedelta(days=rng.choice([365, 730, 1095])),
                    expires_on=expires, status=status,
                    cost=Decimal(rng.choice([15000, 45000, 80000, 180000, 350000])),
                    renewal_lead_days=rng.choice([30, 45, 60, 90]),
                    notes='Renewal handled by the compliance office.'
                    if rng.random() > 0.6 else '',
                )
            self.stdout.write(f'  certifications: {Certification.objects.count()}')

        # ── Safety equipment ─────────────────────────────────────────────
        if _want('equipment'):
            # name, category, maker, model, standard, inspect_days, cal_days,
            # criticality, cost
            equipment_templates = [
                ('Fire extinguisher — CO₂ 5kg', 'fire', 'Naffco', 'CO2-5', 'EN 3-7',
                 30, 365, 'high', 9500),
                ('Fire extinguisher — DCP 9kg', 'fire', 'Naffco', 'DCP-9', 'EN 3-7',
                 30, None, 'high', 7200),
                ('Fire hose reel & cabinet', 'fire', 'Rosenbauer', 'HR-25', 'EN 671-1',
                 90, None, 'high', 42000),
                ('Smoke detector — optical', 'detection', 'Hochiki', 'SOC-E', 'EN 54-7',
                 180, 365, 'critical', 6800),
                ('Heat detector', 'detection', 'Hochiki', 'DCD-A', 'EN 54-5',
                 180, 365, 'high', 6200),
                ('SCBA set — 6.8L composite', 'respiratory', 'Draeger', 'PSS-7000', 'EN 137',
                 30, 365, 'critical', 185000),
                ('Escape set — 15 min', 'respiratory', 'MSA', 'SavOx', 'EN 13794',
                 30, 365, 'critical', 96000),
                ('Full body harness', 'fall', 'Petzl', 'Newton', 'EN 361',
                 90, None, 'critical', 18500),
                ('Self-retracting lifeline 10m', 'fall', 'Petzl', 'Sequoia', 'EN 360',
                 90, None, 'critical', 42000),
                ('Gas detector — multi 4-gas', 'gas', 'Honeywell', 'BW-Max', 'EN 60079',
                 30, 180, 'critical', 78000),
                ('First aid kit — Class A', 'first_aid', 'Safety First', 'FA-A', 'ANSI Z308',
                 30, None, 'high', 12500),
                ('Automated external defibrillator', 'first_aid', 'Philips', 'HS1', 'EN 60601',
                 30, 365, 'critical', 210000),
                ('Eyewash station — 500ml', 'eyewash', 'Bradley', 'EW-500', 'ANSI Z358.1',
                 30, None, 'high', 14500),
                ('Safety shower & eyewash combo', 'eyewash', 'Bradley', 'S19-310', 'ANSI Z358.1',
                 30, 180, 'high', 88000),
                ('Spill kit — chemical 20L', 'spill', 'FastAction', 'SK-20', 'ISO 14001',
                 90, None, 'medium', 22000),
                ('Lock-out / tag-out kit', 'loto', 'Master Lock', 'LOTO-S', 'OSHA 1910.147',
                 180, None, 'high', 16500),
                ('Lifting sling — 2T web', 'lifting', 'Crosby', 'WS-2T', 'EN 1492-1',
                 180, None, 'high', 7800),
                ('Personnel rescue tripod', 'rescue', 'Tractel', 'RTS-9', 'EN 795',
                 180, None, 'critical', 145000),
            ]

            locations = [
                'Reception lobby', 'Production floor — bay 2', 'Warehouse rack A',
                'Loading dock', 'Control room', 'Workshop bench 3', 'Outdoor yard',
                'Chemical store', 'Level 2 corridor', 'Generator house', 'Gate house',
            ]
            departments = ['Operations', 'Production', 'Warehousing', 'Maintenance', 'HSE', 'Facilities']

            created_equipment = []
            for s_index, site in enumerate(sites):
                picks = [equipment_templates[(s_index * 3 + j) % len(equipment_templates)]
                         for j in range(7)]
                for t_index, tpl in enumerate(picks):
                    (name, category, maker, model, standard, inspect_days,
                     cal_days, criticality, cost) = tpl
                    # Mix of overdue / due soon / healthy.
                    # next_inspection = last_inspected + interval = today - drift,
                    # so a positive drift means the item is already past due.
                    band = (s_index + t_index) % 6
                    if band == 0:
                        drift = rng.randint(1, 45)               # overdue
                    elif band == 1:
                        drift = -rng.randint(0, 12)              # due within 2 weeks
                    else:
                        drift = -rng.randint(15, max(inspect_days, 16))   # healthy
                    last_inspected = today - timedelta(days=max(inspect_days + drift, 1))
                    status = 'in_service'
                    if band == 0 and rng.random() < 0.35:
                        status = 'out_of_service'
                    elif band == 1 and rng.random() < 0.2:
                        status = 'maintenance'

                    requires_cal = bool(cal_days)
                    last_cal = None
                    if requires_cal:
                        cal_drift = rng.choice([-120, -60, -25, -6, 20])
                        last_cal = today - timedelta(days=max(cal_days + cal_drift, 1))

                    acquired = today - timedelta(days=rng.randint(60, 2900))
                    eq = SafetyEquipment.objects.create(
                        name=name, category=category, status=status,
                        criticality=criticality,
                        asset_tag=f'AST-{site.code}-{rng.randint(1000, 9999)}',
                        serial_number=f'SN{rng.randint(100000, 999999)}',
                        manufacturer=maker, model=model, standard=standard,
                        site=site, location=rng.choice(locations),
                        department=rng.choice(departments), custodian=person(rng),
                        supplier=rng.choice(['Naffco Kenya', 'Draeger EA', 'SafetyFirst Ltd',
                                             'Honeywell Africa', 'MSA Distributors']),
                        acquired_on=acquired,
                        unit_cost=Decimal(cost),
                        useful_life_years=rng.choice([5, 8, 10, 15]),
                        quantity=rng.choice([1, 1, 1, 2, 3]),
                        requires_inspection=True,
                        inspection_interval_days=inspect_days,
                        last_inspected_on=last_inspected,
                        requires_calibration=requires_cal,
                        calibration_interval_days=cal_days or 365,
                        last_calibrated_on=last_cal,
                        notes='',
                    )
                    created_equipment.append(eq)

                    # Inspection history (strictly older than the rolled date)
                    for k in range(rng.randint(1, 3)):
                        performed = last_inspected - timedelta(days=inspect_days * (k + 1))
                        EquipmentInspection.objects.create(
                            equipment=eq,
                            inspection_type=rng.choice(
                                ['routine', 'routine', 'pre_use', 'statutory', 'functional'],
                            ),
                            performed_on=performed,
                            performed_by=person(rng),
                            provider=rng.choice(['', '', 'SGS Kenya', 'KEBS', 'In-house HSE']),
                            result=rng.choice(['pass', 'pass', 'pass_notes']),
                            findings='' if rng.random() > 0.4 else 'Minor wear noted, monitor.',
                            action_taken='',
                            next_due=performed + timedelta(days=inspect_days),
                            cost=Decimal(rng.choice([0, 1500, 3500, 8000])),
                            downtime_hours=rng.choice([0, 0, 1, 2]),
                        )

                    if requires_cal and last_cal:
                        EquipmentInspection.objects.create(
                            equipment=eq, inspection_type='calibration',
                            performed_on=last_cal, performed_by=person(rng),
                            provider=rng.choice(['KEBS', 'SGS Kenya', 'Draeger EA']),
                            result='pass', next_due=last_cal + timedelta(days=cal_days),
                            cost=Decimal(rng.choice([4500, 9000, 15000])),
                            certificate_url='',
                            notes='Certificate filed with the compliance office.',
                        )

            self.stdout.write(f'  safety equipment: {SafetyEquipment.objects.count()}'
                              f' · inspections {EquipmentInspection.objects.count()}')

            # Defects / work orders
            defect_texts = [
                ('Pressure gauge reads below service range — replaced under warranty.', 'medium', 'resolved'),
                ('Seal cracked on the cylinder valve; unit quarantined pending swap.', 'high', 'open'),
                ('Monthly check tag missing from the cabinet.', 'low', 'resolved'),
                ('Harness webbing shows abrasion at the D-ring anchor point.', 'critical', 'in_progress'),
                ('Detector fails bump test — sensor response slow.', 'high', 'awaiting_parts'),
                ('Eyewash bowl cracked, water spray uneven.', 'medium', 'open'),
                ('Lock-out hasp bent, keys stiff to turn.', 'low', 'resolved'),
                ('Sling label illegible — removed from service pending re-tag.', 'medium', 'in_progress'),
                ('AED self-test alarm chirping, battery below threshold.', 'critical', 'open'),
                ('Fire hose reel swivel leaks under pressure.', 'high', 'resolved'),
                ('Spill kit absorbent saturated from previous use.', 'medium', 'resolved'),
                ('Rescue tripod leg locking pin missing.', 'critical', 'open'),
                ('SCBA demand valve free-flows when connected.', 'high', 'in_progress'),
                ('Safety shower pull handle stiff to operate.', 'medium', 'open'),
            ]
            for idx, (text, sev, st) in enumerate(defect_texts):
                eq = rng.choice(created_equipment)
                reported = today - timedelta(days=rng.randint(1, 240))
                resolved = None
                if st == 'resolved':
                    resolved = reported + timedelta(days=rng.randint(1, 20))
                EquipmentDefect.objects.create(
                    equipment=eq, work_order=f'WO-{rng.randint(10000, 99999)}',
                    reported_on=reported, reported_by=person(rng),
                    severity=sev, description=text, status=st,
                    resolved_on=resolved,
                    resolved_by=person(rng) if resolved else '',
                    resolution='Part replaced and function re-tested.' if resolved else '',
                    downtime_hours=rng.choice([0, 2, 4, 8]) if resolved else 0,
                    repair_cost=Decimal(rng.choice([0, 2500, 6000, 18000])) if resolved else 0,
                )
            self.stdout.write(f'  equipment defects: {EquipmentDefect.objects.count()}')

        # ── Medical assessment (HEALTH & COMPETENCE → Medical Assessment) ──
        if _want('assessments'):
            all_sites = list(Site.objects.all())
            site_by_code = {s.code: s for s in all_sites}

            job_specs = [
                # code, title, dept, site code, physical, vision, hearing,
                # surveillance, exposures, tests, immunisations
                ('OPS-FORKLIFT', 'Forklift Operator', 'Logistics', 'MSA-WH', 'medium',
                 'standard', 'standard', 'annual',
                 ['noise', 'whole-body vibration', 'diesel exhaust'],
                 ['audiometry', 'vision screening'], []),
                ('PLT-PRESS', 'Press Shop Operator', 'Production', 'KSM-PL', 'heavy',
                 'basic', 'strict', 'six_monthly',
                 ['noise', 'hand-arm vibration', 'metalworking fluid mist'],
                 ['audiometry', 'spirometry', 'respirator fit test'], ['tetanus']),
                ('PLT-BOILER', 'Boiler Attendant', 'Utilities', 'KSM-PL', 'medium',
                 'basic', 'standard', 'annual',
                 ['heat', 'noise', 'steam', 'carbon monoxide'],
                 ['audiometry', 'spirometry'], []),
                ('LAB-ANALYST', 'Laboratory Analyst', 'Laboratory', 'NRB-LAB', 'light',
                 'strict', 'basic', 'annual',
                 ['chemical reagents', 'biological agents', 'formaldehyde'],
                 ['vision screening', 'hepatitis B serology', 'baseline serum'],
                 ['hepatitis B', 'tetanus']),
                ('WHS-PICKER', 'Warehouse Picker', 'Warehousing', 'NKR-DH', 'medium',
                 'basic', 'basic', 'annual',
                 ['manual handling', 'repetitive strain'],
                 ['vision screening'], []),
                ('FUEL-ATTENDANT', 'Fuel Station Attendant', 'Retail', 'ELD-FT', 'light',
                 'basic', 'basic', 'annual',
                 ['benzene', 'petroleum vapour', 'noise'],
                 ['spirometry', 'urinary mandelic acid'], []),
                ('CON-RIGGER', 'Construction Rigger', 'Construction', 'THK-CS', 'very_heavy',
                 'strict', 'strict', 'quarterly',
                 ['work at height', 'noise', 'silica dust', 'manual handling'],
                 ['audiometry', 'spirometry', 'vision screening', 'vertigo screen'],
                 ['tetanus']),
                ('OFC-ANALYST', 'Risk Analyst', 'Head Office', 'NRB-HO', 'sedentary',
                 'basic', 'none', 'none',
                 ['display screen equipment', 'sedentary posture'],
                 ['vision screening'], []),
                ('DRV-TRUCK', 'Heavy Truck Driver', 'Logistics', 'NKR-DH', 'medium',
                 'strict', 'basic', 'annual',
                 ['whole-body vibration', 'diesel exhaust', 'fatigue'],
                 ['vision screening', 'audiometry', 'fasting glucose'], []),
            ]

            profiles = []
            for (code, title, dept, site_code, physical, vis, hear, tier,
                 exposures, tests, imms) in job_specs:
                profile, _ = JobDemandProfile.objects.get_or_create(
                    code=code,
                    defaults=dict(
                        job_title=title, department=dept,
                        site=site_by_code.get(site_code),
                        physical_demand=physical,
                        vision_standard=vis, hearing_standard=hear,
                        surveillance_tier=tier,
                        min_vision_left='6/9' if vis == 'strict' else '6/12',
                        min_vision_right='6/9' if vis == 'strict' else '6/12',
                        max_hearing_loss_db=25 if hear == 'strict' else 30,
                        hazard_exposures=exposures,
                        mandatory_tests=tests,
                        mandatory_immunisations=imms,
                        required_ppe=[
                            'hi-vis vest', 'safety boots',
                        ] + (['hearing protection'] if 'noise' in exposures else [])
                        + (['respirator'] if any(
                            k in ' '.join(exposures) for k in ('dust', 'vapour', 'mist', 'fume')
                        ) else []),
                        inherent_requirements=(
                            f'Sustained {physical.replace("_", " ")} work; ability to follow '
                            'permit-to-work controls; clear communication for radio and alarm '
                            'response; no uncontrolled chronic condition affecting alertness.'
                        ),
                    ),
                )
                profiles.append(profile)
            self.stdout.write(f'  job demand profiles: {len(profiles)}')

            examiners = ['Dr. Wanjiru Kamau', 'Dr. Peter Ochieng', 'Dr. Fatuma Ali',
                         'Dr. Samuel Kiptoo']
            providers = ['Aegis Occupational Health Clinic',
                         'Nairobi Occupational Health Centre',
                         'Mombasa Maritime Clinic']

            findings_pool = [
                ('cardiovascular', 'Raised blood pressure, 148/94 on two readings', 'major', False,
                 'Repeat BP in 4 weeks; salt reduction; review if sustained'),
                ('respiratory', 'Reduced FEV1/FVC ratio consistent with early obstruction',
                 'major', True, 'Spirometry in 6 months; dust control review'),
                ('audiology', 'Bilateral 4 kHz notch, 28 dB right / 32 dB left', 'major', True,
                 'Hearing protection mandatory; annual audiometry'),
                ('musculoskeletal', 'Reduced lumbar flexion, positive straight-leg raise',
                 'minor', False, 'Physiotherapy referral; manual handling training'),
                ('ophthalmology', 'Corrected acuity 6/9 both eyes, adequate for role',
                 'normal', False, ''),
                ('dermatology', 'Contact dermatitis on both forearms', 'minor', True,
                 'Nitrile gloves; barrier cream; review in 8 weeks'),
                ('general', 'No abnormality detected', 'normal', False, ''),
                ('metabolic', 'Fasting glucose 6.4 mmol/L', 'minor', False,
                 'Dietary advice; repeat fasting glucose in 3 months'),
                ('neurological', 'Reduced vibration sense in both feet', 'major', False,
                 'Diabetic screen; restrict lone working until reviewed'),
                ('mental_health', 'Reported sleep disturbance after night-shift rotation',
                 'minor', False, 'Shift pattern review; EAP referral'),
            ]

            lab_pool = [
                ('Haemoglobin', 13.2, 15.8, 'g/dL', 13.0, 17.0),
                ('Fasting glucose', 5.4, 6.4, 'mmol/L', 3.9, 5.5),
                ('Creatinine', 78, 96, 'µmol/L', 62, 106),
                ('ALT', 24, 61, 'U/L', 10, 40),
                ('Total cholesterol', 4.2, 5.9, 'mmol/L', 0, 5.2),
                ('Urinary mandelic acid', 0.2, 1.4, 'g/L', 0, 0.8),
                ('Blood lead', 18, 34, 'µg/dL', 0, 20),
                ('Hepatitis B surface antigen', 0, 0, 'index', 0, 1),
            ]

            created_assessments = 0
            for idx, (name, ref) in enumerate(people[:78]):
                profile = profiles[idx % len(profiles)]
                site = profile.site or (all_sites[0] if all_sites else None)

                if idx % 13 == 4:
                    kind = 'exit'
                elif idx % 11 == 7:
                    kind = 'periodic'
                elif idx % 17 == 9:
                    kind = 'return_to_work'
                elif idx % 19 == 3:
                    kind = 'transfer'
                else:
                    kind = 'pre_employment'

                # Spread the schedule across the last 20 months.
                scheduled = today - timedelta(days=rng.randint(0, 600))
                if idx % 9 == 0:
                    scheduled = today + timedelta(days=rng.randint(1, 45))

                is_future = scheduled > today
                height = rng.choice([158, 162, 168, 172, 176, 181, 185])
                weight = height - 100 + rng.choice([-8, -4, 0, 4, 9, 15, 22, 30])
                systolic = rng.choice([112, 118, 121, 126, 132, 138, 146, 152, 164])
                diastolic = rng.choice([68, 72, 76, 80, 84, 92, 98])
                hear_r = rng.choice([8, 10, 12, 15, 18, 22, 26, 30, 34])
                hear_l = hear_r + rng.choice([-4, 0, 0, 2, 4, 6])
                fev1 = round(rng.uniform(2.3, 4.4), 2)
                fvc = round(fev1 + rng.uniform(0.4, 1.1), 2)

                fitness = 'pending'
                status = 'scheduled'
                if not is_future:
                    roll = rng.random()
                    if roll < 0.56:
                        fitness = 'fit'
                    elif roll < 0.80:
                        fitness = 'fit_with_restrictions'
                    elif roll < 0.92:
                        fitness = 'temporarily_unfit'
                    else:
                        fitness = 'unfit'
                    if idx % 7 == 0:
                        status = 'in_progress'
                        fitness = 'pending'
                    elif idx % 5 == 0:
                        status = 'completed'
                    else:
                        status = 'certified'

                work_related = kind == 'exit' and idx % 26 == 4
                compensation = work_related and idx % 52 == 4

                assessment = HealthAssessment.objects.create(
                    kind=kind, status=status,
                    employee_name=name, employee_ref=ref,
                    national_id=f'{rng.randint(20000000, 39999999)}',
                    date_of_birth=date(
                        rng.randint(1968, 2001), rng.randint(1, 12), rng.randint(1, 28)
                    ),
                    gender=rng.choice(['Female', 'Male']),
                    phone=f'+2547{rng.randint(10000000, 99999999)}',
                    job_title=profile.job_title, department=profile.department,
                    site=site, job_demand=profile,
                    scheduled_on=scheduled,
                    examined_on=None if is_future or status == 'scheduled'
                    else scheduled + timedelta(days=rng.randint(0, 6)),
                    examiner_name=rng.choice(examiners),
                    provider=rng.choice(providers),
                    provider_ref=f'PRV-{rng.randint(1000, 9999)}',
                    vital_signs={} if is_future else {
                        'height_cm': height, 'weight_kg': weight,
                        'bp_systolic': systolic, 'bp_diastolic': diastolic,
                        'pulse': rng.choice([58, 62, 68, 72, 76, 84, 96]),
                        'resp_rate': rng.choice([14, 16, 16, 18, 20]),
                        'temperature_c': round(rng.uniform(36.2, 37.4), 1),
                        'spo2': rng.choice([94, 96, 97, 98, 99]),
                        'waist_cm': round(weight * 1.02 + rng.choice([-6, 0, 4, 9])),
                    },
                    vision={} if is_future else {
                        'right_unaided': rng.choice(['6/9', '6/12', '6/18', '6/24']),
                        'left_unaided': rng.choice(['6/9', '6/12', '6/18', '6/24']),
                        'right_corrected': rng.choice(['6/6', '6/6', '6/9']),
                        'left_corrected': rng.choice(['6/6', '6/6', '6/9']),
                        'colour_vision': rng.choice(
                            ['Normal', 'Normal', 'Normal', 'Deficient (red-green)']
                        ),
                        'near_vision': 'N5 both eyes',
                    },
                    hearing={} if is_future else {
                        'right_db': hear_r, 'left_db': hear_l,
                        'audiogram_shape': rng.choice(
                            ['Normal', 'Normal', 'High-frequency notch', 'Presbyacusis']
                        ),
                        'noise_induced': hear_r >= 26,
                    },
                    spirometry={} if is_future else {
                        'fev1_l': fev1, 'fvc_l': fvc,
                        'fev1_fvc_pct': round(fev1 / fvc * 100, 1),
                        'predicted_pct': rng.randint(78, 108),
                    },
                    history={} if is_future else {
                        'past_medical': rng.choice(
                            ['Nil significant', 'Hypertension on amlodipine',
                             'Asthma — inhaler as needed', 'Type 2 diabetes, diet controlled']
                        ),
                        'surgical': rng.choice(['Nil', 'Appendicectomy 2014', 'Nil']),
                        'medications': rng.choice(['Nil', 'Amlodipine 5 mg od', 'Salbutamol PRN']),
                        'allergies': rng.choice(['Nil known', 'Penicillin', 'Nil known']),
                        'occupational': f'{rng.randint(1, 14)} years in {profile.department}',
                        'smoker': rng.choice(['Never', 'Never', 'Ex-smoker', 'Current, 8/day']),
                        'alcohol': rng.choice(['Nil', 'Occasional', 'Weekly']),
                        'exercise': rng.choice(['Walks daily', 'Sedentary', 'Gym 2×/week']),
                    },
                    immunisations=(
                        [{'name': i, 'status': 'current',
                          'given_on': str(today - timedelta(days=rng.randint(90, 900)))}
                         for i in profile.mandatory_immunisations]
                    ),
                    fitness=fitness,
                    restrictions={
                        'fit_with_restrictions': rng.choice([
                            'No work at height above 2 m',
                            'Hearing protection mandatory in all production areas; no lone '
                            'working in the press shop',
                            'Maximum manual lift 15 kg; avoid repetitive overhead work',
                            'No night-shift rotation for 3 months',
                        ]),
                        'temporarily_unfit': 'Fit to resume after specialist review and '
                                              'control of blood pressure',
                        'unfit': 'Unfit for this role; redeployment to a sedentary position '
                                 'recommended',
                    }.get(fitness, ''),
                    recommendations={
                        'fit': 'Routine surveillance per role tier',
                        'fit_with_restrictions': 'Restrictions communicated to the line '
                                                 'supervisor; review at next surveillance',
                        'temporarily_unfit': 'Review in 6 weeks with specialist report',
                        'unfit': 'Occupational physician review; redeployment assessment',
                    }.get(fitness, ''),
                    work_related=work_related,
                    attributable_condition=(
                        'Bilateral noise-induced hearing loss, 12 dB shift at 4 kHz, '
                        'consistent with sustained press-shop exposure'
                        if work_related else ''
                    ),
                    compensation_claim=compensation,
                    exit_reason=rng.choice([
                        'resignation', 'retirement', 'redundancy', 'contract_end',
                        'medical', 'transfer_out',
                    ]) if kind == 'exit' else '',
                    clearance_notes=(
                        'All PPE returned; no outstanding medical follow-up. '
                        'Exit certificate issued for the compensation file.'
                        if kind == 'exit' else ''
                    ),
                    notes='' if is_future else 'Reviewed by the occupational physician.',
                )

                # Certificates on completed & certified records.
                if status in ('completed', 'certified') and assessment.examined_on:
                    months = profile.review_interval_months or 12
                    if status == 'certified':
                        assessment.certificate_no = (
                            f'FIT/{assessment.examined_on.year}/'
                            f'{assessment.pk:05d}'
                        )
                        assessment.issued_on = assessment.examined_on
                        assessment.valid_until = assessment.examined_on + timedelta(
                            days=int(months * 30.4)
                        )
                    if profile.review_interval_months:
                        assessment.next_due = assessment.examined_on + timedelta(
                            days=int(months * 30.4)
                        )
                    assessment.save(update_fields=[
                        'certificate_no', 'issued_on', 'valid_until', 'next_due',
                    ])

                # Findings & investigations on examined records only.
                if not is_future and status != 'scheduled':
                    for f_spec in rng.sample(findings_pool, rng.randint(1, 3)):
                        system, text, severity, wr, rec = f_spec
                        AssessmentFinding.objects.create(
                            assessment=assessment, system=system, finding=text,
                            severity=severity,
                            work_related=wr and kind == 'exit',
                            fit_impact='restrict' if severity in (
                                'major', 'critical') else 'none',
                            recommendation=rec,
                        )
                    for l_spec in rng.sample(lab_pool, rng.randint(2, 4)):
                        analyte, low_v, high_v, unit, ref_low, ref_high = l_spec
                        AssessmentLabResult.objects.create(
                            assessment=assessment, analyte=analyte,
                            value=str(rng.choice([low_v, high_v])), unit=unit,
                            reference_low=ref_low, reference_high=ref_high,
                        )

                created_assessments += 1

            # ── Baseline linkage for exit records ────────────────────────
            # Without this an exit medical cannot demonstrate drift, which is
            # the whole point of the statutory record.
            by_employee = {}
            for a in HealthAssessment.objects.filter(
                kind='pre_employment', examined_on__isnull=False,
            ).order_by('examined_on'):
                by_employee.setdefault(a.employee_name, a)

            linked = 0
            for exit_assessment in HealthAssessment.objects.filter(kind='exit'):
                baseline = by_employee.get(exit_assessment.employee_name)
                if baseline and baseline.pk != exit_assessment.pk:
                    # Re-derive the exit measurements from the baseline so the
                    # pair describes one person: skeletal height cannot change,
                    # and a hearing threshold that "improved" by 20 dB across a
                    # decade of noise exposure is not a story a clinician can
                    # defend on the witness stand.
                    base_vitals = dict(baseline.vital_signs or {})
                    exit_vitals = dict(exit_assessment.vital_signs or {})
                    base_hear = dict(baseline.hearing or {})
                    exit_hear = dict(exit_assessment.hearing or {})

                    if base_vitals.get('height_cm'):
                        exit_vitals['height_cm'] = base_vitals['height_cm']
                    if base_vitals.get('weight_kg'):
                        exit_vitals['weight_kg'] = int(base_vitals['weight_kg']) + rng.randint(
                            1, 9
                        )
                    if base_vitals.get('bp_systolic'):
                        exit_vitals['bp_systolic'] = int(base_vitals['bp_systolic']) + rng.randint(
                            2, 18
                        )
                    for ear in ('right_db', 'left_db'):
                        if base_hear.get(ear) is not None:
                            exit_hear[ear] = int(base_hear[ear]) + rng.choice([0, 2, 6, 10, 14])

                    exit_assessment.vital_signs = exit_vitals
                    exit_assessment.hearing = exit_hear
                    exit_assessment.baseline = baseline
                    exit_assessment.save(update_fields=[
                        'vital_signs', 'hearing', 'baseline',
                    ])
                    linked += 1
                elif baseline is None:
                    # No prior pre-employment record exists for this person, so
                    # synthesise one so the drift comparison has a benchmark.
                    synthetic = HealthAssessment.objects.create(
                        kind='pre_employment', status='certified',
                        employee_name=exit_assessment.employee_name,
                        employee_ref=exit_assessment.employee_ref,
                        job_title=exit_assessment.job_title,
                        department=exit_assessment.department,
                        site=exit_assessment.site,
                        job_demand=exit_assessment.job_demand,
                        scheduled_on=exit_assessment.scheduled_on - timedelta(
                            days=rng.randint(900, 2200)
                        ),
                        examiner_name=rng.choice(examiners),
                        provider=rng.choice(providers),
                        vital_signs={
                            **{k: v for k, v in (exit_assessment.vital_signs or {}).items()},
                            'weight_kg': max(
                                55,
                                int((exit_assessment.vital_signs or {})
                                    .get('weight_kg', 78)) - rng.randint(2, 9),
                            ),
                            'bp_systolic': max(
                                105, int((exit_assessment.vital_signs or {})
                                         .get('bp_systolic', 128)) - rng.randint(4, 14)
                            ),
                        },
                        vision=exit_assessment.vision,
                        hearing={
                            **(exit_assessment.hearing or {}),
                            'right_db': max(
                                4, int((exit_assessment.hearing or {})
                                       .get('right_db', 16)) - rng.randint(4, 12)
                            ),
                            'left_db': max(
                                4, int((exit_assessment.hearing or {})
                                       .get('left_db', 18)) - rng.randint(4, 12)
                            ),
                        },
                        spirometry={
                            **(exit_assessment.spirometry or {}),
                            'fev1_l': round(
                                float((exit_assessment.spirometry or {}).get('fev1_l') or 3.2)
                                + rng.uniform(0.1, 0.5), 2
                            ),
                        },
                        fitness='fit',
                        recommendations='Baseline established on entry',
                    )
                    synthetic.examined_on = synthetic.scheduled_on
                    synthetic.certificate_no = f'FIT/{synthetic.scheduled_on.year}/{synthetic.pk:05d}'
                    synthetic.issued_on = synthetic.scheduled_on
                    synthetic.valid_until = synthetic.scheduled_on + timedelta(days=730)
                    synthetic.save(update_fields=[
                        'examined_on', 'certificate_no', 'issued_on', 'valid_until',
                    ])
                    exit_assessment.baseline = synthetic
                    exit_assessment.save(update_fields=['baseline'])
                    linked += 1

            self.stdout.write(
                f'  health assessments: {created_assessments} '
                f'({linked} exit records baselined)'
            )

        # ── Staff & access (SECURITY & SETTINGS → Staff) ─────────────────
        if _want('staff'):
            # Users live in the shared `public` schema and are scoped by their
            # `tenant` FK, while StaffProfile is tenant-scoped.
            tenant = Tenant.objects.filter(schema_name=schema).first()
            staff_specs = [
                ('Grace', 'Wanjiku', 'hse_manager',
                 'NEBOSH IGC · MSc Occupational Health & Safety', 'HSE/2019/0412', 14, True),
                ('Martin', 'Kariuki', 'safety_officer',
                 'NEBOSH IGC · OSHA 30-hour', 'SO/2021/1187', 9, True),
                ('Purity', 'Chebet', 'safety_officer',
                 'IOSH Managing Safely', 'SO/2022/1544', 6, True),
                ('Samuel', 'Odhiambo', 'safety_officer',
                 'NEBOSH IGC', 'SO/2023/2031', 4, True),
                ('Lydia', 'Muthoni', 'occ_health_nurse',
                 'BSc Nursing · Occupational Health certificate', 'NCK/2017/8834', 11, True),
                ('Irene', 'Nyambura', 'occ_health_nurse',
                 'Diploma in Nursing · Audiometry technician', 'NCK/2020/4417', 7, True),
                ('Joseph', 'Wekesa', 'supervisor',
                 'Diploma in Mechanical Engineering', '', 12, True),
                ('Rachel', 'Achieng', 'supervisor',
                 'BSc Environmental Science', '', 5, True),
                ('Brian', 'Mutiso', 'supervisor',
                 'Higher Diploma in Construction Management', '', 8, True),
                ('Nancy', 'Wanjiku', 'supervisor',
                 'Diploma in Chemical Engineering', '', 10, False),
                ('Felix', 'Barasa', 'supervisor',
                 'Certificate in Warehouse Operations', '', 3, True),
                ('Violet', 'Kirui', 'supervisor',
                 'BSc Industrial Chemistry', '', 6, False),
            ]
            promo_pw = 'OhsmsPass2026'
            seeded_staff = 0
            for first_name, last_name, role, qualification, licence, years, available in staff_specs:
                email = f'{first_name.lower()}.{last_name.lower()}@aegisohs.co'
                user = User.objects.filter(email=email).first()
                if user is None:
                    user = User(
                        email=email,
                        first_name=first_name,
                        last_name=last_name,
                        role=role,
                        phone=f'+2547{rng.randint(10000000, 99999999)}',
                        tenant=tenant,
                        is_active=True,
                    )
                    user.set_password(promo_pw)
                    user.save()
                else:
                    user.first_name = first_name
                    user.last_name = last_name
                    user.role = role
                    if tenant and not user.tenant_id:
                        user.tenant = tenant
                    user.is_active = True
                    user.save()
                StaffProfile.objects.update_or_create(
                    user=user,
                    defaults={
                        'license_number': licence,
                        'qualification': qualification,
                        'years_of_experience': years,
                        'is_available': available,
                        'bio': 'Site safety leadership and day-to-day compliance.',
                    },
                )
                seeded_staff += 1
            self.stdout.write(f'  staff profiles: {seeded_staff}')

        self.stdout.write(self.style.SUCCESS(f'OHSMS seed complete for "{schema}".'))

import{_ as L}from"./BaIJOSOY.js";import{_ as B,u as G,L as F,k as N,f as U,m as p,w as t,ca as H,o as n,a as o,b as i,p as m,d as s,V as b,t as l,n as c,J as j,c as h,F as g,A as y,D as z,q as f}from"./DCLtTqmg.js";import{V as x}from"./enyTQeBb.js";import{V as W}from"./BuwPeWhu.js";import{V as u}from"./B_DxXHu6.js";import{V as S}from"./DioxZdsW.js";import{V as $,a as C}from"./2A8z_4Aj.js";import{V as K,a as T}from"./Vqe44zNk.js";import{V as Z,a as J}from"./8ERYc3tL.js";import{V as Y}from"./DIO_sb2s.js";import{V as Q}from"./DaksrJhb.js";import"./CYTioL0w.js";import"./DCB-DN7T.js";import"./Bb0pAY6h.js";const X={class:"docs-root"},ee={class:"top-nav d-flex align-center px-4 px-md-12 py-3"},te={class:"d-flex align-center mb-2 flex-wrap ga-2"},ie={class:"text-h4 text-md-h3 font-weight-bold mb-2"},ae={class:"text-h6 font-weight-light mb-4",style:{opacity:"0.92","max-width":"880px"}},oe={class:"d-flex align-center mb-3"},se={class:"text-h5 font-weight-bold section-title"},ne={class:"text-caption section-tagline"},re=["innerHTML"],le={key:0,class:"mt-3"},ce=["innerHTML"],de={__name:"docs",setup(pe){const A=new Date().toLocaleDateString(void 0,{year:"numeric",month:"short"});function M(){typeof window<"u"&&window.print()}const v=G(),R=F(),r=N(v.query.tab==="homecare"?"homecare":"pharmacy");U(r,d=>{R.replace({query:{...v.query,tab:d}})});const E=f(()=>r.value==="homecare"?"AdhereMed Homecare Platform":"AdhereMed Pharmacy Platform"),V=f(()=>r.value==="homecare"?"A comprehensive user guide covering every homecare module — from patient enrolment and care plans to medication doses, vitals, teleconsult, and family portal.":"A comprehensive user guide covering every pharmacy module — from POS and inventory to deliveries, branches, purchase orders, and analytics."),w=f(()=>r.value==="homecare"?_:O),O=[{id:"getting-started",title:"Getting Started",icon:"mdi-rocket-launch",color:"teal",tagline:"Sign in, navigate, and orient yourself.",body:`
      <p>After signing in you land on the <b>Dashboard</b>, which surfaces today's KPIs:
      sales, transactions, low-stock counts, pending deliveries, and shift status.</p>
      <ul>
        <li><b>Sidebar</b> — primary navigation between modules. Pinned modules appear at the top.</li>
        <li><b>Top bar</b> — global search, notifications, theme toggle (light/dark), and your profile menu.</li>
        <li><b>Branch switcher</b> — if your pharmacy has multiple branches, switch context from the top bar.</li>
        <li><b>Roles</b> — features are gated by role: <i>super_admin</i>, <i>tenant_admin</i>, <i>pharmacist</i>, <i>cashier</i>, <i>driver</i>.</li>
      </ul>`,tips:[{type:"info",text:"<b>Tip:</b> Press <kbd>Ctrl</kbd>+<kbd>K</kbd> in any module that supports search to focus the search box."}]},{id:"pos",title:"Point of Sale (POS)",icon:"mdi-cash-register",color:"success",tagline:"Sell, accept payments, print receipts.",body:`
      <p>The POS is your daily sales terminal. Open a <b>shift</b> with an opening float before selling, and close it at end of day to generate a Z-report.</p>
      <h4>Selling</h4>
      <ol>
        <li>Search for an item by name, barcode, or SKU.</li>
        <li>Click the item to add it to the cart. Adjust quantity, discount, or unit price inline.</li>
        <li>Choose a <b>customer</b> (walk-in by default) and a <b>payment method</b>: Cash, Card, M-Pesa, Insurance, or Split.</li>
        <li>For Insurance, select the scheme; the eligible portion is deducted automatically.</li>
        <li>Click <b>Charge</b>. A receipt dialog appears — print or close. Stock is decremented and a transaction is recorded.</li>
      </ol>
      <h4>Held / parked sales</h4>
      <p>Use <b>Hold</b> to park a cart and resume it later (e.g., the customer is fetching their card). Held carts persist across shift sessions.</p>
      <h4>Refunds & voids</h4>
      <p>Open the transaction in <i>POS → History</i>, click the row, and choose <b>Refund</b> or <b>Void</b>. Refunds restore stock; voids do not.</p>`,tips:[{type:"warning",text:"<b>Shift required:</b> sales are blocked until you open a shift. Cashiers can only see their own shifts."},{type:"success",text:"Receipts now show your tenant name and a <i>Powered by AdhereMed</i> footer."}]},{id:"pos-history",title:"POS History & Analytics",icon:"mdi-history",color:"indigo",tagline:"Audit, search, export.",body:`
      <p><i>POS → History</i> lists every transaction with filters by date, payment method, cashier, and customer.</p>
      <ul>
        <li>The numbered table shows transaction #, time, items, totals, and status. Click a row to expand the line items.</li>
        <li><b>Export</b> downloads CSV of the filtered set.</li>
        <li><b>Analytics</b> button opens the deeper analytics dashboard (revenue trends, payment mix, hour-of-day, top products).</li>
        <li>Click the receipt icon to reprint. Both the dialog and the printed copy use the tenant name.</li>
      </ul>`},{id:"inventory",title:"Inventory & Stock",icon:"mdi-package-variant-closed",color:"amber-darken-2",tagline:"Items, batches, transfers, counts.",body:`
      <p>Manage every medication and consumable in one place.</p>
      <h4>Catalog</h4>
      <ul>
        <li><b>Stocks</b> — the master list. Each item has cost, selling price, discount %, reorder level, category, unit, and on-hand quantity.</li>
        <li><b>Categories</b> and <b>Units</b> — create taxonomy used across forms and reports.</li>
        <li><b>Batches</b> — every receipt creates a batch with quantity, cost, and expiry. Stock movements are deducted FIFO by expiry.</li>
      </ul>
      <h4>Bulk editor</h4>
      <p><i>Inventory → Bulk</i> opens a spreadsheet-style editor. Use <b>?mode=edit</b> to inline-edit name, category, unit, prices, reorder level, and quantity for many rows at once. Use <b>?mode=delete</b> to multi-select and remove items.</p>
      <h4>Transfers</h4>
      <p>Move stock between branches. The source branch's quantity decreases when the transfer is created; the destination's increases on receipt.</p>
      <h4>Stock counts</h4>
      <p>Create a count, optionally scoped to a branch and category. Enter physical counts; variances are highlighted with monetary impact.</p>`,tips:[{type:"info",text:"Low-stock items appear with a red pill in any list. The dashboard <i>Low stock</i> KPI links directly here."}]},{id:"purchase-orders",title:"Purchase Orders",icon:"mdi-cart-arrow-down",color:"primary",tagline:"Procure stock from suppliers, track GRNs.",body:`
      <p>Use POs to formalize stock procurement.</p>
      <h4>Creating a PO</h4>
      <ol>
        <li>Pick a supplier (or type a name to create a new one).</li>
        <li>Add items. For each: pick from existing stocks <i>or</i> type a new item name to auto-create on save.</li>
        <li>Enter quantity, <b>unit cost</b>, optional <b>selling price</b>, discount %, batch #, and expiry date.</li>
        <li>The form shows a live <b>profit margin</b> chip per line and a Projected Revenue / Projected Profit / Margin % summary at the bottom.</li>
        <li>Save as <i>Draft</i>, <i>Sent</i>, or <i>Received</i>. Saving as Received automatically creates batches and updates stock cost & selling price.</li>
      </ol>
      <h4>Returning a PO</h4>
      <p>Open the PO and click <b>Return</b>. A preview shows which units have already been consumed; check <b>Force return</b> to remove only the remaining stock. Selling and cost prices are reverted to their pre-PO values.</p>
      <h4>Goods Received Notes (GRN)</h4>
      <p>For partial deliveries, mark the PO as <i>Partially Received</i> and create GRNs as goods arrive.</p>`,tips:[{type:"success",text:"Profit margin colors: green ≥ 30%, blue ≥ 15%, amber ≥ 0%, red < 0%."}]},{id:"accounts",title:"Accounts",icon:"mdi-bank",color:"teal-darken-2",tagline:"Income, expenses, receivables & payables — your full financial position.",body:`
      <p>The <i>Accounts</i> module unifies your financial picture across the pharmacy. Open it from the sidebar and switch tabs from the toolbar (or via URL: <code>/accounts?tab=...</code>).</p>
      <h4>Overview</h4>
      <ul>
        <li><b>KPI cards</b> — total revenue, total expenses, net profit/loss, outstanding receivables, outstanding payables, and AdhereMed platform consumption charges for the selected period.</li>
        <li><b>Top receivables</b> and <b>top payables</b> lists with quick links into the full tabs.</li>
        <li><b>Date range selector</b> — Today, Last 7 days, Month to date, Last 90 days, Year to date, or a custom range. The chosen range filters every tab.</li>
      </ul>
      <h4>Receivables</h4>
      <p>Money owed to you — unpaid POS invoices, insurance claims awaiting reimbursement, and customer credit. Aging buckets (current, 1–30, 31–60, 60+ days) highlight risk. Click an invoice to view detail or record a payment.</p>
      <h4>Payables</h4>
      <p>Money you owe — supplier invoices from received POs, expense bills, and platform charges. Aging buckets show overdue amounts. Mark a payable as paid to clear it from the queue.</p>
      <h4>Transactions</h4>
      <p>A unified ledger of every cash movement: POS sales, refunds, expense payments, supplier payments, transfers, and adjustments. Filter by type, account, payment method, and date. Export to CSV.</p>
      <h4>Profit &amp; Loss</h4>
      <p>Income statement for the selected range: revenue (by stream — POS, services, deliveries), cost of goods sold (from batches), gross profit, operating expenses (by category), and net profit. Compare with the previous period for trend.</p>
      <h4>Balance Sheet</h4>
      <p>Snapshot of your financial position as of the selected date. Three sections:</p>
      <ul>
        <li><b>Assets</b> — cash on hand &amp; in bank, receivables, inventory at cost (from current batches), and fixed assets.</li>
        <li><b>Liabilities</b> — payables, supplier balances, platform charges due, and any loans.</li>
        <li><b>Equity</b> — owner's capital plus retained earnings (cumulative net profit). The sheet always satisfies <code>Assets = Liabilities + Equity</code>.</li>
      </ul>
      <p>Switch the <i>As of</i> date to view a historic balance sheet; export to CSV or PDF for filings.</p>
      <h4>General Ledger</h4>
      <p>Double-entry ledger view of every account (Cash, Bank, Receivables, Payables, Sales Revenue, COGS, each Expense category, etc.). For each account you see opening balance, period debits, period credits, and closing balance.</p>
      <ul>
        <li>Click an account to drill into its <b>journal entries</b> with date, source document (POS #, PO #, expense ID), counterpart account, debit/credit, and running balance.</li>
        <li>Filter by account type (Asset, Liability, Equity, Income, Expense), date range, or text search on memo.</li>
        <li>Use <b>Trial Balance</b> from the toolbar to verify total debits equal total credits before closing a period.</li>
        <li>Manual journal entries can be posted from the <b>+ Entry</b> button (admin only) for adjustments such as depreciation or accruals.</li>
      </ul>
      <h4>Exports</h4>
      <p>Use the <b>Export</b> menu in the toolbar to download Receivables, Payables, Transactions, P&amp;L, Balance Sheet, or General Ledger as CSV for accountants or external bookkeeping tools.</p>`,tips:[{type:"info",text:"<b>Tip:</b> AdhereMed platform consumption charges appear as a recurring payable; settle them from the Payables tab to keep service active."},{type:"warning",text:"Receivables &amp; payables are derived from POS, claims, POs, and expenses — record those accurately and the financials reconcile automatically."}]},{id:"dispensing-prescriptions",title:"Dispensing & Prescriptions",icon:"mdi-pill",color:"pink",tagline:"Fulfill prescriptions safely.",body:`
      <p>Prescriptions can originate from in-house consultations or external uploads.</p>
      <ul>
        <li><b>Pending</b> — queue awaiting dispense. Pick batches per item; stock moves are recorded.</li>
        <li><b>Counsel</b> — capture dispensing notes (dosage instructions, warnings) printed on the label.</li>
        <li><b>Substitutions</b> — when an item is out of stock, choose a substitute; the original Rx is preserved for audit.</li>
        <li><b>Dispensed history</b> — search by patient, prescriber, or date range.</li>
      </ul>`},{id:"pharmacy-profile-branches",title:"Pharmacy Profile & Branches",icon:"mdi-store",color:"blue",tagline:"Tenant settings, branches, geo data.",body:`
      <p><i>Settings → Pharmacy Profile</i> stores your business name, license number, logo, hours, services, delivery radius, and insurance acceptance.</p>
      <h4>Branches</h4>
      <p>Create one branch per physical location. The address field accepts <b>three input methods</b>:</p>
      <ol>
        <li><b>Manual entry</b> — just type into the textarea.</li>
        <li><b>Google Places search</b> — type to autocomplete and pick a result; latitude, longitude, and place name are saved.</li>
        <li><b>Pick on map</b> — opens a draggable Google Map. Search, drop the marker, or use GPS. Toggle fullscreen for precision.</li>
      </ol>
      <p>Mark exactly one branch as <b>Main</b>. Inactive branches are excluded from POS, transfers, and reports.</p>`,tips:[{type:"info",text:"Branch coordinates power delivery distance, store-finder UIs, and route optimization."}]},{id:"deliveries",title:"Deliveries",icon:"mdi-moped",color:"deep-purple",tagline:"Last-mile fulfillment with GPS.",body:`
      <p>Each POS transaction with a delivery component creates a delivery record.</p>
      <h4>Workflow</h4>
      <ol>
        <li><b>Create</b> — link the POS transaction (searchable, or enter manually). Capture recipient name, phone, address, and delivery fee.</li>
        <li><b>Address</b> uses the same picker as branches: manual, Places search, or "use my location" GPS. Lat/lng are stored.</li>
        <li><b>Assign driver</b> — pick a staff user or type a free-text driver name (combobox accepts both).</li>
        <li><b>Status flow</b>: Pending → Assigned → In Transit → Delivered (or Failed / Cancelled).</li>
        <li><b>Detail</b> view shows GPS chip and "Open in Maps" link.</li>
      </ol>`},{id:"reports-analytics",title:"Reports & Analytics",icon:"mdi-chart-line",color:"cyan",tagline:"Insights into sales, profit, stock health.",body:`
      <p>The <b>Reports</b> hub bundles ready-made reports keyed by URL (e.g. <code>/reports/sales</code>). Each report supports date-range filters, branch scope, and CSV export.</p>
      <ul>
        <li><b>Sales</b> — gross / net / tax / discount, grouped by day, cashier, payment method, or category.</li>
        <li><b>Profit</b> — revenue minus cost from batches; per item and per category.</li>
        <li><b>Stock</b> — on-hand value, expiring batches (30/60/90 days), slow movers, dead stock.</li>
        <li><b>Purchases</b> — PO totals by supplier, lead times, and outstanding GRNs.</li>
        <li><b>Deliveries</b> — completion rate, average time, driver performance.</li>
      </ul>
      <p><b>Analytics</b> dashboard provides charts: revenue trend, payment mix, hour-of-day heatmap, and top products. Use the date picker in the toolbar.</p>`},{id:"staff-shifts",title:"Staff & Shifts",icon:"mdi-account-group",color:"orange",tagline:"Users, roles, cash drawers.",body:`
      <p>Manage staff under <i>Staff</i>: invite users, set role, assign branch and specialization, activate/deactivate.</p>
      <h4>POS shifts</h4>
      <ul>
        <li>Each cashier opens a shift with an opening float.</li>
        <li>Sales and payments accrue against the shift.</li>
        <li>Closing the shift requires entering the counted cash; variance is recorded automatically.</li>
        <li>The Z-report summarizes totals by payment method and item categories.</li>
      </ul>`},{id:"billing-insurance",title:"Billing & Insurance",icon:"mdi-shield-check",color:"green",tagline:"Schemes, claims, commissions.",body:`
      <p>Configure accepted insurance providers under <i>Settings → Insurance</i>. Each provider has its own price list, allowed items, and claim format.</p>
      <ul>
        <li>At POS, choose the insurance scheme; eligible portion is calculated and the patient covers the balance.</li>
        <li><b>Claims</b> screen tracks submitted, approved, rejected, and paid claims with timestamps and amounts.</li>
        <li><b>Commissions</b> — track partner / referrer commissions on dispensed items.</li>
      </ul>`},{id:"expenses",title:"Expenses",icon:"mdi-cash-minus",color:"red",tagline:"Track operating costs.",body:`
      <p>Record expenses by category (rent, utilities, salaries, marketing, etc.). Attach receipts. Recurring expenses can be templated. Expense totals are netted against revenue in the Profit report.</p>`},{id:"notifications-messaging",title:"Notifications & Messaging",icon:"mdi-bell-ring",color:"purple",tagline:"Stay informed.",body:`
      <p>The bell icon in the top bar shows recent system events: low stock, expiring batches, new prescriptions, delivery updates, shift reminders. Click an item to jump to the source. Use <i>Settings → Notifications</i> to mute categories or change channels (in-app, email, SMS).</p>`},{id:"tips-troubleshooting",title:"Tips & Troubleshooting",icon:"mdi-lifebuoy",color:"blue-grey",tagline:"Common issues and quick fixes.",body:`
      <ul>
        <li><b>Maps don't load</b> — the Google Maps API key may be invalid or domain-restricted. Contact support.</li>
        <li><b>Receipt doesn't print</b> — check browser pop-up blocker; allow pop-ups for the site.</li>
        <li><b>Stock looks wrong</b> — open the item, view <i>Batches</i>, and verify recent PO/GRN entries. Returns reverse stock and prices.</li>
        <li><b>Can't open a shift</b> — close any prior open shift first; only one shift per cashier per branch.</li>
        <li><b>Permission denied</b> — your role doesn't allow the page. Ask an admin to elevate your role under Staff.</li>
      </ul>`}],_=[{id:"hc-getting-started",title:"Getting Started",icon:"mdi-rocket-launch",color:"teal",tagline:"Sign in, navigate the homecare workspace.",body:`
      <p>Homecare tenants land on a dashboard tuned to in-home patient care: today's visits, due doses, overdue vitals, open escalations, and unread messages.</p>
      <ul>
        <li><b>Roles</b>: <i>tenant_admin</i> / <i>homecare_admin</i> manage everything; <i>caregiver</i> sees only "My Day" / assigned patients; <i>patient</i> sees the family-portal experience.</li>
        <li><b>Sidebar</b> groups: <i>Patients</i>, <i>Care Team</i>, <i>Schedules</i>, <i>Medications</i>, <i>Telehealth &amp; Alerts</i>, <i>Family &amp; Admin</i>, <i>Analytics</i>, <i>Clinical Tools</i>.</li>
        <li>Use the branch / company switcher in the top bar if your homecare provider operates multiple companies.</li>
      </ul>`},{id:"hc-patients",title:"Patients",icon:"mdi-account-group",color:"blue",tagline:"Enrol, profile, and manage patient records.",body:`
      <p><i>Patients → All Patients</i> lists every enrolled patient with quick filters by status, primary caregiver, and condition.</p>
      <h4>Enrolling a patient</h4>
      <ol>
        <li>Click <b>Enrol Patient</b> and complete demographics, address, emergency contacts, allergies, and primary diagnosis.</li>
        <li>Attach insurance details if applicable.</li>
        <li>Assign a primary caregiver and care team members on the right-rail.</li>
        <li>Save — the patient appears in the list and on the assigned caregivers' My Day.</li>
      </ol>
      <p>The patient detail page hosts tabs for Overview, Treatment Plan, Medications, Doses, Vitals, Notes, Consents, and Insurance — each linking back to its dedicated module.</p>`,tips:[{type:"info",text:"Use <b>Care Pathways</b> to apply a templated bundle of plans, medications, and vitals schedules at enrolment."}]},{id:"hc-care-team",title:"Care Team & Caregivers",icon:"mdi-account-tie",color:"indigo",tagline:"Staff, assignments, scope of work.",body:`
      <p><i>Caregivers</i> manages the workforce: nurses, midwives, caregivers. Each caregiver has a profile with skills, certifications, working hours, and active patient load.</p>
      <h4>Assignments</h4>
      <p><i>Assignments</i> creates the link between a caregiver and a patient with start/end dates and role (primary, backup, specialist). Assignments power scheduling defaults, dose responsibility, and escalation routing.</p>`},{id:"hc-schedules",title:"Schedules & Visits",icon:"mdi-calendar-clock",color:"deep-purple",tagline:"Plan, track, and complete in-home visits.",body:`
      <p>Two views over the same data:</p>
      <ul>
        <li><b>Visit list</b> — sortable table of upcoming, in-progress, and completed visits with caregiver, patient, time, and status.</li>
        <li><b>Calendar</b> — day / week / month view with drag-to-reschedule.</li>
      </ul>
      <h4>Workflow</h4>
      <ol>
        <li>Create a visit (or it is auto-generated from the patient's care pathway / dose schedule).</li>
        <li>Caregiver checks in (GPS captured), performs tasks, records vitals/notes/doses.</li>
        <li>Checks out — visit is marked Completed; a note appears on the patient timeline.</li>
      </ol>
      <p><b>My Day</b> is the caregiver-focused view of today's visits with quick-action buttons.</p>`},{id:"hc-treatment-plans",title:"Treatment Plans & Care Pathways",icon:"mdi-clipboard-text",color:"cyan-darken-2",tagline:"Goals, interventions, review cycles.",body:`
      <p>A treatment plan groups goals, interventions, and review dates for a patient.</p>
      <ul>
        <li>Create from a blank plan or apply a <b>Care Pathway</b> template.</li>
        <li>Each goal has a target, measurement method, and due date. Mark progress as you review.</li>
        <li>Plans are versioned — every revision keeps an audit trail of who changed what and when.</li>
        <li>Generate a printable plan summary for the family portal.</li>
      </ul>`},{id:"hc-medications-doses",title:"Medications & Doses (MAR)",icon:"mdi-pill",color:"pink",tagline:"Adherence, scheduling, administration record.",body:`
      <p><b>Medications</b> hosts a patient's active medication list with dose, route, frequency, indication, and start/stop dates.</p>
      <h4>Doses (MAR)</h4>
      <p>Each scheduled dose appears in <i>Doses</i> as a tile with status: Due, Given, Refused, Missed, Held. Caregivers tap to record administration, capture witness PIN, and add notes.</p>
      <ul>
        <li><b>Drug interactions</b> are checked at prescribe-time — alerts surface in the prescription form.</li>
        <li>Late doses raise an <b>Escalation</b> automatically per the patient's risk band.</li>
        <li>Adherence % is calculated nightly and shown on the patient overview and reports.</li>
      </ul>`,tips:[{type:"warning",text:"<b>PIN required</b> for high-alert medications. Configure which classes need a PIN under <i>Clinical Catalog</i>."}]},{id:"hc-prescriptions",title:"Prescriptions",icon:"mdi-prescription",color:"pink-darken-2",tagline:"Issue, refill, share with pharmacies.",body:`
      <p>Prescribers create prescriptions linked to the patient and treatment plan. Each Rx supports refills, electronic share with partner pharmacies, and printing.</p>`},{id:"hc-vitals",title:"Vitals & Observations",icon:"mdi-heart-pulse",color:"red",tagline:"Capture, trend, alert.",body:`
      <p>Capture BP, HR, SpO2, temperature, glucose, weight, pain score, and custom observations.</p>
      <ul>
        <li>Out-of-range values are highlighted; severe values trigger an <b>EWS</b> recalculation and may auto-create an escalation.</li>
        <li>Trend charts on the patient overview show 7-day / 30-day windows.</li>
        <li>Set per-patient observation schedules (e.g. BP twice daily) and the system generates due reminders.</li>
      </ul>`},{id:"hc-notes-consents",title:"Care Notes & Consents",icon:"mdi-note-edit",color:"orange",tagline:"Document and authorise.",body:`
      <p><b>Care Notes</b> capture narrative documentation per visit: SOAP-style or free-form, with attachments. Notes are immutable once signed; addenda can be added.</p>
      <p><b>Consents</b> stores patient-signed forms (treatment, telehealth, photography, data sharing). Each consent has a scope, expiry, and PDF copy.</p>`},{id:"hc-teleconsult",title:"Teleconsult",icon:"mdi-video",color:"blue-darken-2",tagline:"Video visits with patients and family.",body:`
      <p>Schedule a teleconsult from the patient detail or directly under <i>Teleconsult</i>. The system generates a one-tap join link for the patient/family and adds the visit to the caregiver's calendar. Notes and recordings (if consented) attach back to the patient timeline.</p>`},{id:"hc-escalations",title:"Escalations & Inbox",icon:"mdi-alert-octagram",color:"red-darken-2",tagline:"Triage urgent issues.",body:`
      <p><b>Escalations</b> queue surfaces urgent items: missed high-risk doses, abnormal vitals, EWS spikes, and caregiver SOS. Each escalation has severity, owner, status, and resolution notes.</p>
      <p><b>Inbox</b> consolidates internal messages from family, caregivers, and the system. Use it as a daily action queue.</p>`,tips:[{type:"warning",text:"Configure escalation routing rules under <i>Clinical Protocols</i> so the right person is notified instantly."}]},{id:"hc-mail",title:"Mail",icon:"mdi-email",color:"indigo-darken-2",tagline:"Provider email, in-context.",body:`
      <p>The Mail module connects an SMTP/IMAP mailbox to your homecare workspace, so referrals, reports, and family correspondence live alongside clinical records. Configure server settings under <i>Mail Settings</i>.</p>`},{id:"hc-family",title:"Family Portal",icon:"mdi-account-multiple-plus",color:"green",tagline:"Engage relatives in the care plan.",body:`
      <p>Invite family members from the patient profile. They get a limited-scope login that shows the care plan, recent vitals, doses, upcoming visits, and a secure message thread with the care team. Permissions are configurable per relative.</p>`},{id:"hc-insurance-billing",title:"Insurance & Billing",icon:"mdi-shield-account",color:"green-darken-2",tagline:"Coverage, claims, invoices.",body:`
      <p><b>Insurance</b> stores each patient's schemes, member numbers, coverage caps, and pre-authorisations. Eligibility is checked when scheduling chargeable services.</p>
      <p><b>Billing</b> generates invoices from completed visits and dispensed medications. Submit to insurers, track claim status, and record payments.</p>`},{id:"hc-equipment",title:"Equipment",icon:"mdi-medical-bag",color:"amber-darken-2",tagline:"Loaned devices and consumables.",body:`
      <p>Track devices issued to patients (oxygen concentrators, infusion pumps, monitors): serial number, issue date, expected return, and maintenance schedule. Alerts fire when service is due.</p>`},{id:"hc-clinical-tools",title:"Clinical Tools",icon:"mdi-clipboard-pulse",color:"teal-darken-2",tagline:"Protocols, EWS, drug interactions, catalog.",body:`
      <ul>
        <li><b>Clinical Protocols</b> — guideline templates that drive escalation routing, dose checks, and observation schedules.</li>
        <li><b>EWS Scoring</b> — configurable Early Warning Score with per-band actions.</li>
        <li><b>Drug Interactions</b> — reference database used at prescribing time.</li>
        <li><b>Clinical Catalog</b> — master lists of medications, vitals types, observation forms, and care pathway templates.</li>
      </ul>`},{id:"hc-reports-audit",title:"Reports & Audit",icon:"mdi-chart-box",color:"cyan",tagline:"Performance and compliance.",body:`
      <p><b>Reports</b> covers visit completion, adherence %, vitals coverage, escalation MTTR, caregiver workload, and revenue. Filter by date, branch, caregiver, or patient cohort. Export CSV.</p>
      <p><b>Audit Log</b> records every clinical and administrative action (who, what, when, before/after). Use it for incident review and accreditation evidence.</p>`},{id:"hc-company-profile",title:"Company Profile",icon:"mdi-domain",color:"blue-grey-darken-2",tagline:"Tenant settings.",body:`
      <p>Set company name, license, logo, address, working hours, and service catalog. These appear on patient invoices, family-portal headers, and public pages.</p>`},{id:"hc-tips",title:"Tips & Troubleshooting",icon:"mdi-lifebuoy",color:"blue-grey",tagline:"Common issues and quick fixes.",body:`
      <ul>
        <li><b>Caregiver can't see a patient</b> — verify an active <i>Assignment</i> exists with today in its date range.</li>
        <li><b>Doses not appearing</b> — ensure the medication has an active schedule and a start date today or earlier.</li>
        <li><b>Family member can't log in</b> — re-send the invite from the patient's <i>Family</i> tab.</li>
        <li><b>Escalation didn't route</b> — check the relevant clinical protocol's notification rules and that the on-call user is active.</li>
      </ul>`}];return(d,e)=>{const I=L,q=H;return n(),p(q,{name:"auth"},{default:t(()=>[o("div",X,[e[14]||(e[14]=o("div",{class:"brand-gradient bg-fill"},null,-1)),e[15]||(e[15]=o("div",{class:"blob blob-1"},null,-1)),e[16]||(e[16]=o("div",{class:"blob blob-2"},null,-1)),o("div",ee,[i(m,{variant:"text",class:"text-none","prepend-icon":"mdi-arrow-left",style:{color:"#fff !important"},onClick:e[0]||(e[0]=a=>d.$router.push("/welcome"))},{default:t(()=>[...e[4]||(e[4]=[s(" Back ",-1)])]),_:1}),i(x),i(I,{size:16,"bold-color":"white","light-color":"white"}),i(x),i(m,{variant:"outlined",class:"text-none mr-2",rounded:"lg",style:{color:"#fff !important","border-color":"rgba(255,255,255,0.7)"},onClick:e[1]||(e[1]=a=>d.$router.push("/login"))},{default:t(()=>[...e[5]||(e[5]=[s(" Sign In ",-1)])]),_:1}),i(m,{color:"white",class:"text-none",rounded:"lg",style:{color:"#0F766E"},onClick:e[2]||(e[2]=a=>M())},{default:t(()=>[i(b,{class:"mr-1"},{default:t(()=>[...e[6]||(e[6]=[s("mdi-printer",-1)])]),_:1}),e[7]||(e[7]=s(" Print ",-1))]),_:1})]),i(W,{class:"docs-container py-8 py-md-10",style:{position:"relative","z-index":"2","max-width":"1280px"}},{default:t(()=>[i(u,{flat:"",rounded:"xl",class:"docs-hero pa-6 pa-md-10 mb-6 text-white"},{default:t(()=>[o("div",te,[i(S,{color:"white",variant:"flat",size:"small",style:{color:"#0F766E","font-weight":"700"}},{default:t(()=>[i(b,{size:"14",start:""},{default:t(()=>[...e[8]||(e[8]=[s("mdi-book-open-variant",-1)])]),_:1}),e[9]||(e[9]=s(" User Guide ",-1))]),_:1}),i(S,{color:"white",variant:"outlined",size:"small"},{default:t(()=>[s("v1.0 · "+l(c(A)),1)]),_:1})]),o("div",ie,l(c(E)),1),o("div",ae,l(c(V)),1),i($,{modelValue:c(r),"onUpdate:modelValue":e[3]||(e[3]=a=>j(r)?r.value=a:null),"bg-color":"transparent",color:"white","slider-color":"white",density:"comfortable",class:"docs-tabs"},{default:t(()=>[i(C,{value:"pharmacy",class:"text-none","prepend-icon":"mdi-pill"},{default:t(()=>[...e[10]||(e[10]=[s("Pharmacy",-1)])]),_:1}),i(C,{value:"homecare",class:"text-none","prepend-icon":"mdi-home-heart"},{default:t(()=>[...e[11]||(e[11]=[s("Homecare",-1)])]),_:1})]),_:1},8,["modelValue"])]),_:1}),i(K,{dense:""},{default:t(()=>[i(T,{cols:"12",md:"3"},{default:t(()=>[i(u,{flat:"",rounded:"lg",class:"docs-toc pa-3 sticky-toc"},{default:t(()=>[e[12]||(e[12]=o("div",{class:"toc-overline mb-1"},"Contents",-1)),i(Z,{density:"compact",nav:"",class:"bg-transparent toc-list"},{default:t(()=>[(n(!0),h(g,null,y(c(w),a=>(n(),p(J,{key:a.id,href:`#${a.id}`,title:a.title,"prepend-icon":a.icon,rounded:"lg"},null,8,["href","title","prepend-icon"]))),128))]),_:1})]),_:1})]),_:1}),i(T,{cols:"12",md:"9"},{default:t(()=>[(n(!0),h(g,null,y(c(w),a=>(n(),p(u,{key:a.id,id:a.id,flat:"",rounded:"lg",class:"docs-section pa-5 pa-md-7 mb-4"},{default:t(()=>{var k;return[o("div",oe,[i(Y,{color:a.color||"primary",variant:"tonal",size:"40",class:"mr-3"},{default:t(()=>[i(b,{color:a.color||"primary"},{default:t(()=>[s(l(a.icon),1)]),_:2},1032,["color"])]),_:2},1032,["color"]),o("div",null,[o("div",se,l(a.title),1),o("div",ne,l(a.tagline),1)])]),o("div",{innerHTML:a.body,class:"docs-body"},null,8,re),(k=a.tips)!=null&&k.length?(n(),h("div",le,[(n(!0),h(g,null,y(a.tips,(P,D)=>(n(),p(Q,{key:D,type:P.type||"info",variant:"tonal",density:"compact",class:"mb-2"},{default:t(()=>[o("div",{innerHTML:P.text},null,8,ce)]),_:2},1032,["type"]))),128))])):z("",!0)]}),_:2},1032,["id"]))),128)),i(u,{flat:"",rounded:"lg",class:"pa-5 text-center docs-section"},{default:t(()=>[...e[13]||(e[13]=[o("div",{class:"text-body-2 text-medium-emphasis"},[s(" Need more help? Reach support at "),o("a",{href:"mailto:support@adheremed.com"},"support@adheremed.com"),s(". ")],-1)])]),_:1})]),_:1})]),_:1})]),_:1})])]),_:1})}}},Te=B(de,[["__scopeId","data-v-c80a11ba"]]);export{Te as default};

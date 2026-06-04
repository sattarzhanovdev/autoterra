---
name: autoterra-b2b-buildable-app
description: Use this skill when creating a launchable AutoTerra B2B app, Stitch AI project prompt, frontend prototype, UI system, mobile/web screens, admin cabinets, dashboards, or design specs. The result must implement all product requirements from the B2B platform architecture and strictly follow the AutoTerra guidebook: black/red/white palette, TT Octosquares/TT Neoris typography, chamfered geometry, modular grid, sharp cut forms, thick broken-line icons, and cinematic automotive photo style.
---

# AutoTerra B2B Buildable App

## Primary Rule

Design strictly inside the AutoTerra brand system. Do not invent a new visual style, palette, typography, icon style, rounded SaaS aesthetic, neon sci-fi look, or generic automotive interface.

The product is a B2B platform for body shops, distributors, managers, couriers, admins, and an AI support/knowledge-base flow. It must feel like a precise, technological, reliable service ecosystem for automotive paint, color matching, logistics, expert support, and demand management.

This is not a gift/bonus app and not a direct sales marketplace. It is a federal B2B platform that helps the importer manage demand in the automotive paint and refinishing market through regional distributors, while giving body shops practical services: purchase tracking, SKU history, color matching, fuel-door pickup, delivery, expert Q&A, training materials, AI assistance, recommendations, and referrals.

Key management idea: the product must create demand, retain body shops, route clients to regional distributors, and give the importer transparent market analytics. It must not replace distributor sales, accounting, payment, invoices, debt terms, or financial relationships.

## Brand DNA

AutoTerra is based on mastery, expertise, technology, reliability, flexibility, and speed. The main visual metaphor is attraction: elements pull toward each other, connect in pairs, and form purposeful compositions around a strong center.

Translate this into UI as:

- Strong geometry, sharp angles, chamfered corners, and confident alignment.
- Dense but readable operational screens, not decorative landing pages.
- Paired blocks that visually move toward each other or create a content space between them.
- A sense of precision, control, and professional automotive workflow.
- Minimal effects. No playful softness, glassmorphism, cute illustrations, or glossy consumer app styling.

## Colors

Use only the brand palette and functional tints derived from it.

- Brand black: `#171717`
- Brand red: `#F01D2C`
- Brand white: `#F5F5F5`

Usage:

- Black is the main background for premium, expert, dashboard, AI, and operational surfaces.
- White is the main background for readable forms, tables, product lists, and dense data screens.
- Red is the primary accent for CTAs, active states, alerts, priority tags, key metrics, progress, and brand cuts.
- Gray may be used only as neutral UI support, derived from black/white. Keep it restrained.

Avoid:

- Blue/purple SaaS gradients.
- Cold saturated palettes.
- Neon cyberpunk colors.
- Beige, brown, orange, pastel, or multicolor themes.
- Recoloring the brand mark or using arbitrary accent colors.

## Typography

Use the guidebook fonts when available:

- `TT Octosquares Medium` for headings, compact labels, short accent text, numbers, and key UI emphasis.
- `TT Neoris Regular` for body text and long descriptions.
- `TT Neoris DemiBold` for readable emphasis, table headers, statuses, and important labels.

If fonts are unavailable in Stitch AI, specify: use close geometric square sans for headings and a clean modern sans for body text, while preserving the same hierarchy and character.

Typography rules:

- Headings are compact, technical, and confident.
- Body copy is functional and short.
- Use uppercase sparingly for navigation, chips, small labels, and status tags.
- Keep text aligned to the modular grid.
- Do not use decorative typography, script fonts, playful rounded fonts, or oversized marketing hero text inside app screens.

## Geometry And Components

The core shape language comes from the logo angles and cuts.

Use:

- Chamfered corners instead of normal rounded corners.
- Cut size: about `10-50px` depending on format and component size.
- Compact UI cuts for mobile cards: `8-16px`.
- Larger panel cuts for dashboards and hero modules: `24-50px`.
- Single outlined chamfered forms with `2-4px` stroke when the layout needs less visual weight.
- Red cut corners or red paired fragments for important blocks.
- Straight, angular separators and grid lines.

Avoid:

- Rounded cards, pills, soft blobs, bokeh, orbs, organic waves.
- Nested card-on-card layouts.
- Heavy drop shadows or glossy bevels.
- Generic Material/iOS rounded components unless reshaped into the brand geometry.

## Grid And Layout

Use a strict modular grid.

- Desktop/web: 12-column grid.
- Tablet: 8-column grid.
- Mobile: 4-column grid.
- Keep consistent margins, gutters, and vertical rhythm.
- Align content blocks, images, icons, buttons, and forms to the grid.
- Dense operational screens should prioritize scanning, comparison, and repeated action.

Layout behavior:

- First screen must be the actual product experience, not a marketing page.
- Mobile app screens should show useful workflows immediately: status, actions, requests, purchases, AI support.
- Web cabinets should feel like operational tools: tables, side navigation, filters, dashboards, detail panels.
- Use black high-contrast sections for AI/expert areas and key status dashboards; use white surfaces for forms and data-heavy tables.

## Icons And Illustrations

Icons must match the guidebook:

- Thick-line icons.
- Sharp, laconic geometry.
- Intentional breaks/cuts in strokes.
- Red primary stroke on white or black backgrounds.
- Icon meaning should be functional: order, SKU, color lab, courier, AI, support, referral, stock, document, status.

Illustrations:

- Use linear technical illustrations with broken lines and sharp angles.
- Illustrations should show tools, gestures, process, automotive paint work, color matching, logistics, or expert support.
- Do not use generic 3D mascots, soft vector people, cute onboarding art, or stock SaaS illustrations.

## Photo Direction

When a screen uses images, specify photorealistic cinematic automotive content:

- Technological AutoTerra world.
- Harmony between people and machines.
- Engineering process, precision, automotive paint, body shop, color lab, material testing.
- Soft retro palette with warm neutrals and muted metallic colors.
- Realistic materials, depth, controlled lighting, professional workshop atmosphere.

Avoid:

- Repeated identical faces or poses.
- Cold oversaturated color grading.
- Aggressive sci-fi, excessive neon, hologram overload.
- Empty visuals without people interacting with technology.
- Generic stock cars disconnected from the work process.

## Product Screens To Generate

For Stitch AI, request real product screens from this structure.

Mobile app for body shop:

- Home: client status, distributor, category A/B/C, quick actions.
- Purchases: upload invoice/check, SKU list, verification status, purchase history.
- Order/distributor: request invoice, repeat order, contact distributor.
- Color Lab: request color matching, car/VIN/color/photo, courier pickup of fuel door, request status, recipe history.
- AI assistant: product questions, defect analysis, recommended materials, escalation to Q&A.
- Q&A: expert support thread, AI pre-analysis, expert answer status.
- Referrals: invite body shop, condition based on confirmed first order, gift/status.
- Delivery: pickup/delivery status, courier photo confirmation.
- Notifications: personalized AI recommendations and operational statuses.

Web/admin cabinets:

- Central admin: Russia-wide regions, distributors, clients, purchases, SKU, stock, referrals, AI knowledge base, reports, settings.
- Manager: clients, registration, activation statuses, tasks, comments, contact history.
- Distributor: regional clients, purchase confirmation, stock upload, applications, reports.
- Courier: tasks, routes, statuses, pickup/delivery photo proof.
- AI/knowledge base: tickets, AI pre-analysis, similar cases, knowledge card approval.

Do not create separate mobile cabinets for colorist, technologist, or trainer. Their work belongs to website/admin/internal operational interfaces.

## Business Rules

Always preserve these product rules in screens and flows:

- Importer does not sell directly to body shops. Financial relationships, invoices, payments, receivables, discounts, and terms are between distributor and client.
- Importer works like an exclusive sales department: importer managers may register clients across Russia and develop demand.
- Regional routing is mandatory. Client selects region and enters INN, then the system assigns the regional distributor.
- The app does not replace accounting. It records clients, purchases, SKU, requests, recommendations, support, logistics, and analytics.
- Ecosystem value is more important than a one-time discount: color matching, logistics, AI, Q&A, training, and recommendations create retention.
- Gifts and rewards exist only inside the referral program and only after confirmed real orders.
- Excel/Yandex Disk may be an export/reporting showcase, but not the primary application database. A real server database is required for reliability.

## Roles And Access

Use these roles exactly:

- Super admin / importer: all Russia, regions, distributors, clients, analytics, referral rules, gifts, AI knowledge base, stock, purchases, requests, settings.
- Importer manager: registers clients in any region, transfers them to the distributor, supports activation and repeat sales, handles tasks and comments.
- Distributor: sees regional clients, confirms purchases, issues invoices outside the system, works with orders/requests, uploads stock and product availability, views regional reports.
- Body shop / client: buys from distributor, records purchases, submits color matching/delivery/support requests, recommends other shops.
- Courier: receives pickup/delivery/return tasks, follows routes, updates statuses, adds photo proof.
- AI assistant: uses approved knowledge base, suggests answers, analyzes tickets, asks clarifying questions, escalates complex cases to Q&A.

Excluded mobile roles:

- No separate mobile cabinet for colorist.
- No separate mobile cabinet for technologist.
- No separate mobile cabinet for trainer.

Colorists are employees of the distributor/station operational contour. Technologists and trainers form one expert function working through website/admin/internal tools.

## End-To-End Process

Represent the platform around this process:

1. Registration: client chooses region, enters INN, contacts, and body shop category.
2. Routing: system detects regional distributor and creates client card.
3. Sale: client buys from distributor; distributor issues invoice outside the app.
4. Purchase record: client uploads document or distributor confirms purchase; SKU and sums are stored.
5. Color matching: client creates request, courier picks up fuel door, request goes to distributor/station.
6. Support: AI handles typical questions and escalates complex, risky, defect, or claim cases to Q&A.
7. Analytics: management sees regions, clients, SKU, distributors, managers, referrals, and performance.

Never include payment acceptance, importer invoices, or importer-controlled financial terms in app flows.

## Mobile App Requirements

Body shop mobile app must include:

- Home: client status, distributor, body shop category, quick actions for order, purchase, color matching, fuel-door pickup, support, delivery.
- Service profile: INN, company name, region, city, contacts, A/B/C category, assigned distributor, assigned manager, status.
- My purchases: upload invoice/UPD/receipt/check photo or file, manual amount and SKU entry for MVP, purchase history, verification status, duplicate warnings.
- Order / route to distributor: contact distributor, request invoice, repeat order, request consultation. The app routes demand to distributor rather than selling directly.
- Fuel-door pickup: address, time, contact, car, VIN, color, photos, comment, urgency, delivery method.
- Color Lab: request status, distributor/station queue, recipe/code, materials, comments, history by client/car/VIN/color/date.
- Referral program: invitation link/code, invited shops, registration status, first order fact, order amount, condition completion, gift/reward status.
- AI assistant: product questions, kit suggestions, defect pre-analysis, recommendations, push reminders, escalation to Q&A.
- Q&A: expert support thread, photos/videos, AI pre-analysis, clarifying questions, expert answer status.
- Delivery: order delivery, fuel-door return, courier statuses, photo confirmation.
- Notifications: order, purchase, color matching, delivery, referral, training, and personalized AI recommendations.

## Registration And Routing

Registration must support:

- Region selection as a required field.
- INN as the main client identifier for duplicate prevention, analytics, and purchase history.
- Client category: A = dealer center, B = multi-profile body shop, C = garage service.
- Multiple regions/branches for one INN only with admin confirmation.
- Registration source: client, importer manager, or distributor.
- Client statuses: new, under review, active, blocked, archived.

Use client category for manager priority, segmentation, analytics, support format, and personalized AI recommendations.

## Purchases, SKU, And Stock

Purchase module must track not only sums but exact product positions.

Include:

- Document upload: invoice, UPD, delivery note, check, receipt, photo, or file.
- MVP input: manual sum and SKU entry.
- Later input: OCR and integrations.
- Duplicate checks by INN, document number, date, amount, photo, and status.
- SKU accounting: article/SKU, category, quantity, volume, amount, brand, distributor.
- Distributor stock upload: SKU, name, quantity, availability status, warehouse, update date.
- Availability statuses: in stock, low stock, by order, out of stock.
- Exact stock quantities may be hidden from clients; show availability statuses when needed.

No separate bonus accrual belongs here. Gifts and rewards belong only to referrals.

## Referral Program

Referral program exists for organic client-base growth.

Required flow:

1. Existing client sends link or code to another body shop.
2. New shop enters region and INN.
3. System links the new shop to the inviter.
4. New shop makes first order through its regional distributor.
5. Order is confirmed by document and must exceed the minimum threshold.
6. Inviter receives gift, discount, additional deferred-payment term, or higher status.
7. Any reward connected with discount/deferred payment must be approved with the distributor.

Show invited shops, registration status, purchase fact, purchase amount, whether the condition is complete, and what gift/reward is due.

## Color Lab, Stock, And Logistics

The company has a color matching station, 6 colorists, and a warehouse with paint and body-shop materials. The app includes Color Lab as a service contour but does not create a separate colorist mobile role.

Color Lab must support:

- Color matching request: car, VIN, color, photos, comment, urgency, fuel-door transfer method.
- Courier pickup: client chooses address, time, contact; courier receives task and status.
- Operational queue: requests go to distributor or station; colorists work internally.
- Color recipe: result stores recipe/code, materials, comments.
- Color history: by client, car, VIN, color, and date for faster repeated matching.
- Stock visibility: distributor uploads stock; client can see availability status when appropriate.
- Delivery: delivery order, fuel-door return, transfer photo proof, courier statuses.
- SLA tracking for pickup, color matching, and delivery.

## Expert Support, Training, And AI

AI is a controlled assistant to the expert function. It must not learn or publish technical knowledge by itself.

AI/Q&A flow:

1. Client sends question, photo, or defect video.
2. AI classifies the question, searches similar cases, and asks clarifying questions.
3. Complex questions, claims, defects, and risky cases go to Q&A.
4. Technologist/trainer answers through website/admin panel.
5. AI turns the answer into a draft knowledge card.
6. Responsible expert approves, edits, or rejects the card.
7. Only approved cards are used in future AI answers.

Safety rule: AI must not independently publish new technical recommendations, change mixing proportions, promise warranty results, or recommend compatibility without a confirmed source.

Training requirements:

- Training materials may include lessons, checklists, videos, instructions, and webinar recordings.
- Materials may be shown to clients in the app.
- Materials are managed from admin/website, not from separate trainer mobile cabinet.
- AI may recommend a lesson or instruction based on a question, purchase, or defect.

## Web Cabinets And Admin Sections

Central admin must include:

- Regions, distributors, clients, purchases, referrals, gifts, SKU, stock, AI base, reports, settings.

Manager cabinet must include:

- Clients, registration, activation statuses, tasks, comments, contact history.

Distributor cabinet must include:

- Regional clients, purchase confirmation, product/stock upload, requests, statuses, regional reports.

Courier cabinet must include:

- Tasks, routes, statuses, photos, pickup/delivery confirmation.

AI / knowledge-base cabinet must include:

- Tickets, AI pre-analysis, similar cases, knowledge cards, approval status.

## Data Entities

Design around these entities and fields:

- User: ID, role, phone, email, status, registration date.
- Client / body shop: INN, name, category A/B/C, region, city, contacts, distributor, manager, status.
- Region: code, name, distributor, manager, activity.
- Distributor: name, INN, regions, contacts, status.
- StockItem: distributor, SKU, name, quantity, availability status, warehouse, update date.
- Purchase: client, document, date, amount, status, distributor, region.
- PurchaseItem: SKU, quantity, volume, price, category, brand.
- Referral: inviter, invited shop, status, first order amount, gift.
- ColorRequest: car, VIN, photo, fuel door, status, recipe, responsible contour.
- CourierTask: type, address, time, status, courier, photo proof.
- ExpertTicket: question, photo/video, category, AI answer, expert answer, status.
- KnowledgeCard: problem, causes, solution, SKU, restrictions, approving expert.

## AI Recommendations And Push

Push notifications belong to AI recommendations. They must be personalized from client behavior, purchases, status, region, and support history.

Use these scenarios:

- No recent purchase: remind about repeat order or suggest contacting distributor.
- Referral made purchase: notify that referral condition is complete and gift is ready for confirmation.
- Fuel-door request: courier assigned, fuel door picked up, in progress, ready.
- New training material: recommend lesson related to purchases or support topics.
- Frequent defect: suggest instruction, video, or consultation through Q&A.
- Low regional activity: create development task for manager.
- Typical SKU running out: suggest repeat order through distributor based on purchase history.

## MVP Stages

When asked to prioritize or generate MVP screens, follow:

- MVP 1: registration, region+INN, A/B/C category, distributor binding, purchases, SKU, distributor stock upload, basic admin, reports.
- MVP 2: color matching, courier fuel-door pickup, courier role, request statuses, color history.
- MVP 3: Q&A, AI assistant, human-in-the-loop AI training, knowledge base.
- MVP 4: referral program with gifts only for confirmed purchases of invited clients.
- MVP 5: advanced analytics, AI recommendations, push scenarios, integrations with distributor accounting/warehouse systems.

## Efficiency Requirements

Prioritize:

- Minimum actions for body shop: purchase upload and fuel-door request should take 2-3 steps.
- Partner statuses: Silver, Gold, Platinum, Certified Partner to stimulate repeat purchases and engagement.
- Anti-fraud: INN, duplicate documents, amounts, dates, photos, and statuses.
- Availability statuses instead of exact stock quantities when exact stock should stay hidden.
- Gifts only for real confirmed orders.
- AI through expert approval.
- Unified client history: purchases, color matches, tickets, recommendations, referrals, and gifts in one client card.
- OCR for documents to reduce manual input.
- SLA for color matching, pickup, and delivery.

## Final Product Structure

The final product is a mobile app for body shops plus web cabinets for internal roles, distributors, service operations, and administration.

Contours:

- Body shop: profile, purchases, distributor order, recommendations, courier fuel-door pickup, color matching, AI, Q&A.
- Sales: managers, regions, clients, distributors, activation, tasks, analytics.
- Distributor: regional clients, requests, purchase confirmation, product/stock upload, availability.
- Service: couriers, requests, statuses, SLA, fuel-door pickup, delivery; colorists stay internal.
- Management: dashboards, regions, SKU, distributors, managers, clients, referrals, efficiency.
- AI: knowledge base, tickets, knowledge cards, expert confirmation, recommendations, push scenarios.

## Buildable Project Requirements

When asked to create, generate, or implement the project, deliver a launchable frontend prototype, not only static screens. The project must open locally, have navigation, realistic data, and working UI flows for the main requirements.

Recommended implementation:

- Use React + TypeScript + Vite unless the existing project already uses another stack.
- Use a single-page app with client-side routing or tab-based routing.
- Keep all data local as typed mock data unless a backend is explicitly requested.
- Use local state for filters, forms, status changes, role switching, and demo interactions.
- Persist simple demo changes in memory or `localStorage` when useful.
- Use semantic components and reusable design tokens for colors, typography, cuts, spacing, and statuses.
- Use CSS variables for brand tokens.
- Use responsive layouts for desktop admin and mobile body-shop views.
- Include all required screens as working routes or navigable sections.
- Provide a clear command to run the project locally.

Do not leave placeholder-only pages. Every major module must contain realistic example records, statuses, controls, and at least one meaningful interaction.

## Required App Navigation

The launchable prototype must include navigation for these areas:

- Body shop mobile view: home, profile, purchases, order/distributor, Color Lab, referrals, AI assistant, Q&A, delivery, notifications.
- Admin/management web view: dashboard, regions, distributors, clients, purchases, SKU/stock, referrals/gifts, AI knowledge base, reports, settings.
- Manager web view: clients, activation, tasks, comments, contact history.
- Distributor web view: regional clients, purchase confirmation, stock upload, requests, reports.
- Courier view: tasks, route list, pickup/delivery statuses, photo proof state.
- AI/knowledge-base view: tickets, AI pre-analysis, similar cases, draft knowledge cards, approval status.

Use a role switcher in the prototype so reviewers can move between body shop, admin, manager, distributor, courier, and AI/knowledge-base contexts without login complexity.

## Required Demo Data

Seed the project with realistic mock data for:

- Regions with assigned distributors and managers.
- Distributors with INN, regions, contacts, status.
- Body shops with INN, A/B/C category, city, assigned distributor, manager, status.
- Purchases with documents, dates, amounts, statuses, distributor, region.
- Purchase items with SKU, category, quantity, volume, price, brand.
- Stock items with SKU, availability status, warehouse, update date.
- Referrals with inviter, invited shop, registration status, first order amount, gift.
- Color requests with car, VIN, photos placeholder, fuel-door status, recipe, SLA.
- Courier tasks with type, address, time, status, courier, photo proof.
- Expert tickets with question, media placeholder, category, AI pre-answer, expert answer, status.
- Knowledge cards with problem, causes, solution, SKU, restrictions, approving expert.
- Push recommendations for no purchase, referral completed, fuel-door status, training material, frequent defect, low regional activity, and repeat SKU.

Mock values should be Russian-market appropriate: Russian regions/cities, INN-like values, body-shop names, SKU-like product codes, ruble amounts, and distributor relationships.

## Required Interactions

At minimum, implement these interactive flows:

- Role switcher changes navigation and visible data.
- Registration/routing demo: entering region + INN shows assigned distributor and category/status.
- Purchase upload demo: form accepts document metadata, manual sum, SKU rows, and shows verification/duplicate status.
- Distributor purchase confirmation: distributor can mark a purchase as confirmed/rejected in demo state.
- Stock filtering: filter SKU by availability status and distributor.
- Color Lab request: create or preview request with car, VIN, color, urgency, pickup method, and SLA status.
- Courier status update: change task status through assigned, picked up, in progress, delivered/returned.
- Referral condition check: show whether invited shop has confirmed first order above threshold and whether gift is ready.
- AI ticket flow: AI pre-analysis, escalation to Q&A, expert answer, draft knowledge card, expert approval.
- Push/recommendation list: display personalized recommendations based on mocked client activity.
- Admin dashboard filters: region, distributor, client category, purchase status, referral status.

The interactions can be demo-level and local, but they must visibly reflect the business rules.

## Functional Guardrails

The project must enforce these rules in UI labels, available actions, and demo flows:

- No payment screen.
- No importer invoice creation.
- No direct checkout from importer to body shop.
- Distributor is always the sales and invoice owner.
- Region + INN routing is mandatory before client activation.
- Gifts require confirmed real order above threshold.
- Discount/deferred-payment gift requires distributor approval.
- AI technical advice requires expert-approved source.
- Colorist, technologist, and trainer are not mobile roles.
- Exact stock quantity can be hidden from body shops; availability status is enough.

## UI Implementation Rules

Implement the brand system in code, not only as prompt text:

- Define CSS variables: `--brand-black: #171717`, `--brand-red: #F01D2C`, `--brand-white: #F5F5F5`.
- Use chamfered shapes through `clip-path`, pseudo-elements, or a reusable component/class.
- Avoid `border-radius` except tiny technical values if absolutely necessary for native inputs; main panels/cards/buttons must look cut/chamfered.
- Buttons, cards, tables, tabs, status badges, sidebars, and modals must share the same angular system.
- Use red for primary actions, active navigation, warning/priority states, and brand fragments.
- Use black surfaces for status/AI/expert/dashboard zones and white surfaces for data-heavy forms/tables.
- Use compact typography and dense spacing suitable for repeated operational use.
- Use thick red line icons or a consistent icon style adapted to thick, angular, broken-line geometry.
- Do not use gradients, glassmorphism, floating orbs, bokeh, soft rounded SaaS cards, or generic colorful charts.

## Suggested Project Structure

Use a clear structure such as:

```text
src/
  app/
    App.tsx
    routes.tsx
  data/
    mockData.ts
    types.ts
  components/
    AppShell.tsx
    RoleSwitcher.tsx
    ChamferCard.tsx
    StatusBadge.tsx
    DataTable.tsx
    MetricPanel.tsx
    SectionHeader.tsx
  views/
    body-shop/
    admin/
    manager/
    distributor/
    courier/
    ai/
  styles/
    tokens.css
    global.css
```

This structure is recommended, not mandatory. If the existing repo has patterns, follow them while preserving the same coverage and behavior.

## Launch And Verification

Before delivering a generated project:

- Install dependencies if needed.
- Run typecheck/lint/build if scripts exist.
- Start the dev server.
- Open the app in a browser or otherwise verify it renders.
- Check desktop admin layout and mobile body-shop layout.
- Confirm that navigation works and the required demo interactions respond.
- Confirm the visual style matches the guidebook: black/red/white, chamfered geometry, modular alignment, dense operational UI.

Expected handoff:

- Provide the local URL.
- List the run command.
- Briefly state what screens and flows are included.
- Mention any checks that could not be run.

## Build Prompt Pattern

Use this prompt when asking an AI/code generator to build the whole project:

```text
Build a launchable frontend prototype for AutoTerra B2B platform.

Use React + TypeScript + Vite unless another stack is already present. Create a working app with navigation, typed mock data, local state interactions, responsive desktop/mobile layouts, and all major modules from the product architecture.

Strict product requirements:
- This is a federal B2B platform for importer -> regional distributor -> body shop ecosystem.
- The app creates demand and service retention; it does not sell directly or replace distributor accounting.
- Region + INN routing is mandatory.
- Distributor owns invoices, payments, receivables, discounts, and sales terms.
- Include roles: super admin/importer, importer manager, distributor, body shop, courier, AI assistant/knowledge base.
- Exclude separate mobile roles for colorist, technologist, and trainer.
- Include mobile body-shop modules: home, profile, purchases, distributor order, Color Lab, fuel-door pickup, referrals, AI assistant, Q&A, delivery, notifications.
- Include web cabinets: central admin, manager, distributor, courier, AI/knowledge base.
- Include data entities: User, Client, Region, Distributor, StockItem, Purchase, PurchaseItem, Referral, ColorRequest, CourierTask, ExpertTicket, KnowledgeCard.
- Include interactions: role switcher, registration routing, purchase upload, purchase confirmation, stock filtering, Color Lab request, courier status update, referral condition check, AI ticket approval, recommendations, admin filters.
- AI cannot publish technical advice, mixing proportions, warranty promises, or compatibility claims without expert approval.
- Gifts are only for confirmed real referral orders above threshold.

Strict AutoTerra visual guide:
- Use only #171717, #F01D2C, #F5F5F5 and restrained neutral grays.
- Use TT Octosquares style headings and TT Neoris style body text or close fallbacks.
- Use chamfered/cut panels, cards, buttons, and status components; avoid rounded SaaS cards.
- Use modular grid, dense operational layouts, precise alignment.
- Use thick broken-line red icons.
- Use cinematic automotive workshop imagery only where useful.
- Avoid gradients, neon sci-fi, blue/purple SaaS style, glassmorphism, cute illustrations, decorative blobs.

Deliver a runnable project. Do not leave empty placeholder pages. Every major module must include realistic data, states, and controls.
```

## Stitch AI Prompt Pattern

Use this structure when asking Stitch AI to generate a screen:

```text
Create a [mobile/web] UI screen for AutoTerra B2B platform: [screen name and workflow].

Strictly follow the AutoTerra brand guide:
- palette only #171717 black, #F01D2C red, #F5F5F5 white, restrained neutral grays;
- TT Octosquares style headings and TT Neoris style body text;
- chamfered corners, angular cut panels, no rounded SaaS cards;
- modular grid, dense operational layout, precise alignment;
- thick broken-line red icons;
- cinematic automotive workshop imagery only where useful.

Screen requirements:
- [list the concrete data, controls, states, and actions]
- preserve distributor-led sales and mandatory region+INN routing;
- include relevant roles, statuses, entities, anti-fraud, SLA, or approval states when the screen needs them;
- show real B2B workflow, not marketing copy;
- make CTA and statuses red;
- use black surfaces for premium/AI/status areas and white surfaces for forms/tables;
- keep all text functional, short, and readable.

Avoid: gradients, neon sci-fi, blue/purple SaaS style, soft rounded cards, cute illustrations, generic stock images, glassmorphism, decorative blobs.
```

## Quality Checklist

Before accepting a Stitch AI result, verify:

- Colors are only brand black, brand red, brand white, and restrained neutral grays.
- Corners are chamfered/cut, not rounded.
- Layout uses a visible modular grid and strong alignment.
- UI is operational and feature-complete for the chosen workflow.
- Icons use thick broken-line geometry.
- Photos, if present, show professional automotive process with warm cinematic realism.
- AI is shown as expert support with confirmation/escalation, not as an uncontrolled recommender.
- The app does not process payments or replace distributor financial relationships.
- Referral rewards depend on confirmed real orders, not empty registrations.
- There are no separate mobile roles for colorist, technologist, or trainer.

## Hard Bans

Never output:

- A generic landing page instead of an app screen.
- Rounded gradient SaaS dashboard.
- Blue, purple, neon, beige, brown, orange, pastel, or multicolor identity.
- Cute onboarding characters or soft startup illustrations.
- Recolored or modified logo.
- Arbitrary icon set that ignores the thick broken-line style.
- App flows where importer sells directly, takes payment, or issues invoices instead of the distributor.
- AI recommendations that publish technical advice, mixing proportions, warranty promises, or compatibility claims without expert confirmation.

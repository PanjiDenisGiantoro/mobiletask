# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

One Flutter codebase with a single Material 3 design language, shipped to both Android and iOS phones. On iPhone it still owes iOS its OS guarantees: safe-area insets, edge-swipe back, and Reduce Motion. Tablet layouts are not a confirmed target.

## Users

All roles are equally primary; none is secondary to the others:

- **Employees/staff**: clock in and out, see and update their tasks, submit leave, overtime, reimbursement and cash-advance (kasbon) requests, and read their payslips.
- **Managers/team leads**: track projects and team progress, assign tasks, and approve requests.
- **Owners/HR admins**: manage employees, shifts, holidays, face enrollment, attendance settings and payroll.

Target companies span every size and type: SMEs and startups, agencies and software houses, field and shift-based workforces, and mid-to-large corporations. Future work must not optimize for one segment at another's expense.

## Product Purpose

Flovig is one mobile app for running both the work and the people behind it: project and task management alongside HRIS (attendance, leave, overtime, reimbursement, kasbon, payroll, approvals). Success means a company no longer needs a separate project tool and a separate HR app.

## Positioning

**Projects + HRIS in one app.** The same person who updates a task also clocks in, requests leave, and approves a teammate's overtime without switching products. Competitors are either project tools (Trello, ClickUp) or HR tools (Talenta, Gadjian), not both.

## Operating Context

- The app runs in two modes, **Task Management** (default) and **HRIS**, switched from Profile; the bottom navigation changes with the mode.
- Attendance uses GPS location (geolocator) and optional face recognition, with face enrollment managed by admins.
- Role-based access: owner/manager roles and a `canApprove` permission gate approval flows.
- Also includes chat (threads), support tickets, a calendar, and reports.
- Backend: `https://flovig.com/api`. Sign-in by email/password and Google.

## Capabilities and Constraints

- Stack: Flutter (Material 3), go_router, Lottie and Rive assets, fl_chart, table_calendar.
- **Language: English.** The current UI copy is Indonesian; moving the copy to English is part of upcoming work. Open: whether Indonesian is kept as a second locale.
- Dark mode: not yet implemented; undecided whether it is required.

## Brand Commitments

- The name **Flovig** and the logo (`assets/images/flovig_logo.png`) are final and must be used as-is.

## Evidence on Hand

- No real customers, usage data, or testimonials exist yet.
- **Dummy data is permitted** for development, demo, and empty-state previews, and must be plainly placeholder (no fake company names presented as real customers, no invented metrics or testimonials in shipped marketing claims).
- Assets: logo, a 3D login hero image (`assets/images/login_hero_3d.png`), SVG icons and illustrations (`assets/icons/`), and Lottie animations (`assets/lottie/`).

## Product Principles

1. **One app, two jobs, no seams.** Work and HR should feel like one product; moving between a task and an approval must never feel like switching apps.
2. **Every role is first-class.** Daily employee actions (clock-in, task update, submit a request) and manager or admin actions (approve, assign, configure) both get fast, direct paths.
3. **Fast daily actions.** The most frequent actions, such as clocking in, updating a task, and approving, should take the fewest steps.
4. **Trustworthy with people data.** Attendance, payroll, and approvals deal with pay and fairness, so states, statuses, and confirmations must be unambiguous.
5. **Honest UI.** No buttons that lead nowhere, and no fabricated numbers presented as real.

## Accessibility & Inclusion

Target WCAG 2.1 AA contrast. Meet Material touch targets (48dp) and support system text scaling. The target segments include field and shift workforces, who may use the app outdoors.

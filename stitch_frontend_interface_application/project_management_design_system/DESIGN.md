---
name: Project Management Design System
colors:
  surface: '#faf8ff'
  surface-dim: '#dad9e1'
  surface-bright: '#faf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f4f3fa'
  surface-container: '#eeedf4'
  surface-container-high: '#e9e7ef'
  surface-container-highest: '#e3e1e9'
  on-surface: '#1a1b21'
  on-surface-variant: '#444651'
  inverse-surface: '#2f3036'
  inverse-on-surface: '#f1f0f7'
  outline: '#757682'
  outline-variant: '#c5c5d3'
  surface-tint: '#4059aa'
  primary: '#00236f'
  on-primary: '#ffffff'
  primary-container: '#1e3a8a'
  on-primary-container: '#90a8ff'
  inverse-primary: '#b6c4ff'
  secondary: '#735c00'
  on-secondary: '#ffffff'
  secondary-container: '#fed01b'
  on-secondary-container: '#6f5900'
  tertiary: '#4b1c00'
  on-tertiary: '#ffffff'
  tertiary-container: '#6e2c00'
  on-tertiary-container: '#f39461'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dce1ff'
  primary-fixed-dim: '#b6c4ff'
  on-primary-fixed: '#00164e'
  on-primary-fixed-variant: '#264191'
  secondary-fixed: '#ffe083'
  secondary-fixed-dim: '#eec200'
  on-secondary-fixed: '#231b00'
  on-secondary-fixed-variant: '#574500'
  tertiary-fixed: '#ffdbcb'
  tertiary-fixed-dim: '#ffb691'
  on-tertiary-fixed: '#341100'
  on-tertiary-fixed-variant: '#773205'
  background: '#faf8ff'
  on-background: '#1a1b21'
  surface-variant: '#e3e1e9'
typography:
  headline-xl:
    fontFamily: Manrope
    fontSize: 40px
    fontWeight: '800'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  body-lg:
    fontFamily: Manrope
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-base:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Manrope
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  headline-lg-mobile:
    fontFamily: Manrope
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  xxl: 48px
  container-margin: 24px
  gutter: 16px
---

## Brand & Style
The design system is built on the pillars of **precision, reliability, and velocity**. It is designed for high-performance teams who require a tool that feels both authoritative and frictionless. The aesthetic follows a **Corporate Modern** approach—stripping away unnecessary ornamentation in favor of high-contrast information density and clear hierarchy.

The visual language communicates stability through a deep navy palette while utilizing a vibrant golden yellow to draw immediate attention to critical actions and project milestones. The style prioritizes "Information First" architecture, ensuring that complex project data remains legible and actionable through generous whitespace and a rigorous grid.

## Colors
The palette is engineered for high contrast and professional endurance. 

- **Primary (Navy Blue):** Used for global navigation, primary buttons, and structural branding. It represents the "anchor" of the application.
- **Secondary (Golden Yellow):** Reserved strictly for high-priority calls to action, active states, and "attention" indicators (e.g., overdue tasks). 
- **Neutrals:** A range of slate-tinted grays is used to define surfaces without feeling cold. The background remains a crisp white to maximize the legibility of data-heavy views.
- **Semantic Colors:** Traditional Green (#10b981) for "Completed," Red (#ef4444) for "Blocked," and Blue (#3b82f6) for "In Progress" should be used to augment the primary palette.

## Typography
This design system utilizes **Manrope** across all levels to maintain a geometric yet approachable feel. The typography system is optimized for data density.

- **Headlines:** Use Bold (700) or ExtraBold (800) weights with slight negative letter-spacing to create a strong visual "hit."
- **Body Text:** Uses a standard 16px base for optimal long-form reading in task descriptions and comments.
- **Labels:** Small, semi-bold, and occasionally all-caps labels are used for metadata like tags, dates, and status indicators.
- **Hierarchy:** Ensure a clear vertical rhythm by strictly adhering to the defined line heights, which are calculated on a 4px baseline grid.

## Layout & Spacing
The layout relies on a **12-column fluid grid** for desktop and a **4-column grid** for mobile. 

- **The 8px Rule:** All components and layout blocks must align to an 8px spatial grid. This ensures harmony with the 8px corner radius.
- **Information Density:** For data-heavy views (Gantt charts, tables), a "Compact" mode using 4px padding increments is permitted. For marketing or dashboard summaries, use "Comfortable" spacing (16px+).
- **Safe Areas:** Maintain a minimum 24px margin on all container edges to ensure the UI feels "airy" despite the professional, high-contrast style.

## Elevation & Depth
This design system uses a **Tonal Layering** approach combined with subtle, high-quality shadows to define hierarchy.

- **Level 0 (Base):** White (#ffffff) or Soft Gray (#f8fafc). Used for the main canvas.
- **Level 1 (Cards/Surface):** White surface with a 1px border (#e2e8f0). No shadow. Used for secondary content blocks.
- **Level 2 (Raised):** White surface with a subtle ambient shadow (Y: 2px, Blur: 4px, Opacity: 4% Black). Used for interactive cards and task items.
- **Level 3 (Overlay):** Used for modals and dropdowns. Features a more pronounced shadow (Y: 8px, Blur: 16px, Opacity: 8% Black) and a 1px border to ensure separation from the background.

## Shapes
The shape language is defined by a consistent **8px (0.5rem) radius**. This "Medium" roundedness strikes the balance between the clinical sharpness of traditional corporate software and the friendliness of modern SaaS.

- **Standard Elements:** Buttons, Input fields, and Cards all use the 8px radius.
- **Small Elements:** Checkboxes and small tags use a 4px radius.
- **Exceptions:** Status pills or "User Avatars" may use a full pill/circle radius to differentiate them from functional UI blocks.

## Components
- **Buttons:** 
    - *Primary:* Navy Blue background, White text.
    - *Secondary/Accent:* Golden Yellow background, Dark Charcoal text. Use this for "Create Project" or "Complete Task."
    - *Ghost:* No background, Navy Blue border and text. Used for secondary actions like "Cancel."
- **Input Fields:** Outlined style with a 1px border (#e2e8f0). Focus state uses a 2px Navy Blue border with a soft blue outer glow.
- **Chips/Tags:** 8px rounded corners, using soft tinted backgrounds (e.g., light blue background with dark blue text) to indicate categories without competing with primary buttons.
- **Cards:** White background, 1px border, 8px radius. Use Level 2 elevation on hover to indicate interactivity.
- **Task Lists:** Use high-contrast dividers (#f1f5f9) and ensure 16px padding between text and borders to maintain a clean, professional look.
- **Progress Bars:** Use a 4px height with Navy Blue as the "fill" and a light gray for the "track."
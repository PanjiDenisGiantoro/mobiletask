# ProjectHub Design System

## Color Palette

### Primary
| Name         | Hex       | Usage                        |
|--------------|-----------|------------------------------|
| Primary 900  | #0D1B6E   | Dark background, headers      |
| Primary 800  | #1A237E   | Splash background, nav bar    |
| Primary 700  | #283593   | AppBar, sidebar               |
| Primary 600  | #3949AB   | Buttons, active states        |
| Primary 400  | #5C6BC0   | Hover, secondary buttons      |
| Primary 200  | #9FA8DA   | Disabled states, borders      |
| Primary 50   | #E8EAF6   | Card backgrounds, light fill  |

### Accent
| Name         | Hex       | Usage                        |
|--------------|-----------|------------------------------|
| Accent 400   | #26C6DA   | Highlight, badges, progress  |
| Accent 200   | #80DEEA   | Light accents                |

### Semantic
| Name       | Hex       | Usage              |
|------------|-----------|--------------------|
| Success    | #43A047   | Done, completed    |
| Warning    | #FB8C00   | In Progress        |
| Error      | #E53935   | Overdue, critical  |
| Info       | #1E88E5   | Informational      |

### Neutral
| Name         | Hex       | Usage                    |
|--------------|-----------|--------------------------|
| Grey 900     | #212121   | Body text                |
| Grey 700     | #616161   | Secondary text           |
| Grey 400     | #BDBDBD   | Placeholder, dividers    |
| Grey 100     | #F5F5F5   | Page background          |
| White        | #FFFFFF   | Card surface             |

---

## Typography

| Style         | Font Size | Weight    | Usage                        |
|---------------|-----------|-----------|------------------------------|
| Display       | 32sp      | Bold 700  | Splash title                 |
| Headline 1    | 24sp      | Bold 700  | Screen titles                |
| Headline 2    | 20sp      | SemiBold  | Section headers              |
| Subtitle 1    | 16sp      | Medium    | Card titles, list items      |
| Subtitle 2    | 14sp      | Medium    | Labels, chips                |
| Body 1        | 14sp      | Regular   | Body text                    |
| Body 2        | 12sp      | Regular   | Descriptions, captions       |
| Caption       | 10sp      | Regular   | Timestamps, metadata         |

---

## Spacing Scale

| Token  | Value | Usage                     |
|--------|-------|---------------------------|
| xs     | 4dp   | Inner padding micro       |
| sm     | 8dp   | Compact padding           |
| md     | 16dp  | Default padding           |
| lg     | 24dp  | Section padding           |
| xl     | 32dp  | Screen padding            |
| xxl    | 48dp  | Large section gaps        |

---

## Border Radius

| Token    | Value | Usage                    |
|----------|-------|--------------------------|
| small    | 8dp   | Chips, tags              |
| medium   | 12dp  | Cards                    |
| large    | 16dp  | Modals, bottom sheets    |
| full     | 100dp | Avatars, FABs, buttons   |

---

## Elevation / Shadow

| Level | dp  | Usage                    |
|-------|-----|--------------------------|
| 0     | 0   | Flat surfaces            |
| 1     | 2   | Cards (resting)          |
| 2     | 4   | Cards (hover)            |
| 3     | 8   | Dropdowns, menus         |
| 4     | 16  | Dialogs, modals          |

---

## Components

### ProjectCard
- Size: full-width or half-grid
- Background: White
- Radius: 12dp
- Elevation: 2dp
- Padding: 16dp
- Contains: title, tag chip, progress bar, member avatars, due date

### StatCard
- Size: flexible (1/2 or 1/3 grid)
- Background: Primary 50 or accent tint
- Radius: 12dp
- Elevation: 1dp
- Contains: icon, value, label

### TaskTile
- Full-width list item
- Contains: checkbox, title, priority chip, assignee avatar, due date
- Divider between items: Grey 100

### BottomNavBar
- Background: White
- Active icon color: Primary 600
- Inactive icon color: Grey 400
- Items: Home, Projects, Tasks, Messages, Profile

### Avatar
- Sizes: sm (24dp), md (32dp), lg (48dp)
- Stacked overlap: -8dp
- Border: 2dp White

### PriorityChip
- High: Error bg tint, Error text
- Medium: Warning bg tint, Warning text
- Low: Success bg tint, Success text

---

## Screen List

| Screen               | File                        |
|----------------------|-----------------------------|
| Splash               | splash_screen.dart          |
| Home / Dashboard     | home_screen.dart            |
| Projects List        | projects_screen.dart        |
| Project Detail       | project_detail_screen.dart  |
| Tasks                | tasks_screen.dart           |
| Messages             | messages_screen.dart        |
| Profile              | profile_screen.dart         |

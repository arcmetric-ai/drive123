# Drive Tutor — Next.js Website

Ontario's driving lesson platform. Built with Next.js 14, deployable to Vercel in one command.

## 🚀 Deploy to Vercel

### Option 1 — Vercel CLI (fastest)
```bash
npm i -g vercel
cd drivetutor
npm install
vercel
```

### Option 2 — GitHub + Vercel Dashboard
1. Push this folder to a GitHub repo
2. Go to vercel.com → New Project
3. Import your GitHub repo
4. Framework will auto-detect as Next.js
5. Click Deploy ✅

### Option 3 — Local dev first
```bash
npm install
npm run dev        # http://localhost:3000
npm run build      # production build
npm start          # serve production build
```

## 📁 Project Structure

```
src/
├── app/
│   ├── layout.tsx              # Root layout (fonts, metadata, theme init)
│   ├── page.tsx                # Home page (hero, features, screenshots, download)
│   ├── privacy-policy/page.tsx
│   ├── terms-and-conditions/page.tsx
│   ├── data-consent-policy/page.tsx
│   ├── refund-policy/page.tsx
│   ├── cookie-policy/page.tsx
│   ├── community-guidelines/page.tsx
│   ├── safety-policy/page.tsx
│   ├── instructor-verification/page.tsx
│   ├── account-deletion/page.tsx
│   └── contact/page.tsx
├── components/
│   ├── Navbar.tsx              # Nav with dark mode toggle + mobile menu
│   ├── Footer.tsx              # Footer with all policy links
│   └── PolicyLayout.tsx        # Reusable layout for all policy pages
└── styles/
    └── globals.css             # All styles + CSS tokens + responsive breakpoints
```

## 🎨 Customisation

### Update App Store links
In `src/app/page.tsx`, search for `href="#"` on the store buttons and replace with your live links.

### Add real app screenshots
Replace the `screen-frame` placeholder divs in the screenshots section with `<Image>` components pointing to your actual screenshots in `/public/screenshots/`.

### Update policy content
Each policy page is in its own file under `src/app/`. Edit the JSX content directly.

### Brand colours
Edit the CSS variables in `src/styles/globals.css` under `:root` and `:root.dark`.

## 🌙 Dark Mode
Automatically respects the user's OS preference on first load. Users can toggle manually with the 🌙/☀️ button in the nav. Preference is saved to localStorage.

## 📱 Mobile
- Hamburger menu on screens < 640px
- Fluid typography with `clamp()`
- Touch-friendly tap targets (min 44px)
- Single-column layouts on small screens
- Horizontal-scrollable screenshot carousel

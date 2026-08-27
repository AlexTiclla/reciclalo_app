# Picker Flow Design Prompt

## Overview
Design prototype screens for the **Recolector (Picker)** role in the EcoRecicla app. The picker views nearby recycling pickup requests on a map, can review details, accept/reject requests, and manage completed pickups.

---

## User Context
- **Role**: Recolector / Operador (waste picker/collector)
- **Primary Action**: Browse nearby pickup requests on an interactive map and accept/reject them
- **Device**: Mobile (390×844 viewport)
- **Design System**: EcoHarmony (Primary Green #0f5238, Mint #95d5b2, Neutral Background #f8f9fa)

---

## Flow Overview

```
Map View 
  ↓
Request Details (tap pin)
  ↓
Confirm Accept/Reject (dialog)
  ↓
Post-Accept View (if accepted)
  ↓
Mark as Done
```

---

## Screen 1: Picker Map View

### Purpose
Show available pickup requests near the picker's current location on an interactive map.

### Key Elements
- **Header**: "Pickups Nearby" with active request count badge (e.g., "3 active")
- **Map Display**: 
  - Simplified map view with location pins for each nearby request
  - Each pin shows the material type (e.g., "Plástico", "Papel", "Vidrio")
  - One pin should be highlighted/emphasized (e.g., center with green dot) showing the current focus request
  - Pins display a label with material type and price if applicable (e.g., "Papel - $5")
  - Map can be interacted with (pan, zoom) but nothing fancy
  
- **Bottom Sheet Preview**:
  - Shows a preview of the tapped/highlighted request
  - Contains:
    - Thumbnail image of recyclables
    - Title (e.g., "Papel y Cartón")
    - Distance with location icon (e.g., "📍 850m away")
    - Price in green (e.g., "$5 en efectivo" or "Gratis")
    - Arrow indicator suggesting swipe up for full details
  
- **Floating Action Button** (bottom right):
  - Compass/location icon
  - Allows picker to center map on their current location
  
- **Interactions**:
  - Tap pin → expand bottom sheet with full details
  - Swipe up on bottom sheet → go to Screen 2 (Request Details)
  - Tap compass FAB → re-center map on user location

### Design Notes
- Use EcoHarmony primary green for active/highlighted elements
- Keep the map clean and minimal — no extraneous overlays
- Bottom sheet should be draggable/expandable to show full card

---

## Screen 2: Request Details

### Purpose
Display full details of a selected pickup request. Allow picker to make an accept/reject decision.

### Key Elements
- **Header**:
  - Close/back button (top left)
  - Request status chip (e.g., "Disponible" / "Pending")
  
- **Image Section**:
  - Large image/photo of the recyclables (full width)
  - If no image, show a neutral placeholder
  
- **Details Card**:
  - **Title**: Material type (e.g., "Papel y Cartón")
  - **Description**: User's message/notes about the pickup
  - **Price**: 
    - Display prominently in green
    - Show if free ("Gratis") or cash amount ("$5 en efectivo")
  - **Location Section**:
    - Small map preview with pin showing pickup location
    - Allow user to interact with this map (pan/zoom)
    - Address/area name
    - Distance to pickup
  - **Contact Section**:
    - WhatsApp button (primary action)
    - Opens WhatsApp pre-filled with a message ready to chat/call about the pickup
  
- **Action Buttons** (at bottom, full width):
  - **Accept Button** (Primary Green): "Aceptar" — confirms acceptance
  - **Reject Button** (Secondary/Ghost): "Rechazar" — declines the request
  
- **Interactions**:
  - Tap WhatsApp button → open WhatsApp with pre-filled message
  - Tap "Aceptar" → go to Screen 3 (Confirmation Dialog)
  - Tap "Rechazar" → dismiss and return to map view
  - Interact with map preview (zoom/pan)

### Design Notes
- Keep layout vertical and scrollable if content is long
- WhatsApp button should be visually distinct (maybe with WhatsApp icon)
- Action buttons should be sticky at the bottom or easily reachable
- Use good contrast for readability

---

## Screen 3: Confirmation Dialog

### Purpose
Confirm the picker's decision to accept a pickup request before committing.

### Key Elements
- **Modal/Dialog Overlay**:
  - Semi-transparent dark background
  - Centered white card container
  
- **Dialog Content**:
  - **Heading**: "¿Aceptar esta solicitud?" (Are you sure you want to accept this request?)
  - **Summary**: 
    - Show material type, location distance, and price
    - Brief preview so user can confirm they have the right request
  - **Action Buttons**:
    - **Confirm** (Primary Green): "Sí, aceptar" — commits the acceptance
    - **Cancel** (Ghost/Secondary): "Cancelar" — returns to Screen 2
  
- **Interactions**:
  - Tap "Sí, aceptar" → go to Screen 4 (Post-Accept View)
  - Tap "Cancelar" → return to Screen 2 (Request Details)
  - Tap outside dialog (optional) → cancel and return to Screen 2

### Design Notes
- Dialog should feel lightweight and quick to dismiss
- Use high contrast for button clarity
- No animations needed — keep it simple

---

## Screen 4: Post-Accept View

### Purpose
Show the accepted request with options to navigate to the pickup location and contact the requester.

### Key Elements
- **Header**:
  - Close/back button
  - Status chip: "Aceptado" (Accepted) in green
  
- **Status Summary**:
  - Confirm message: "¡Solicitud aceptada!" (Request accepted!)
  - Brief details (material type, price)
  
- **Location Map**:
  - Map showing the pickup location with a pin
  - Simple, clean display
  - Allow basic interaction (zoom/pan) but nothing complex
  - Show distance and estimated time if available
  
- **Action Buttons** (prominent, full width or side-by-side):
  - **Google Maps Button**: "Ir a Google Maps" (Open in Google Maps)
    - Opens Google Maps with the pickup location pinned
  - **WhatsApp Button**: "Contactar por WhatsApp" (Request location via WhatsApp)
    - Opens WhatsApp with a pre-filled message (e.g., "¿Dónde exactamente está el punto de recolección?")
  - **Mark as Done Button**: "Marcar como completado" (Mark as Done)
    - Changes appearance or moves to a "pending pickup" or "in progress" state
    - After tapping, picker can confirm pickup is complete
  
- **Interactions**:
  - Tap "Ir a Google Maps" → open Google Maps navigation
  - Tap "Contactar por WhatsApp" → open WhatsApp with location request message
  - Tap "Marcar como completado" → show confirmation or mark pickup as done
  - Interact with map (zoom/pan)

### Design Notes
- Use green accents to reinforce the "accepted" state
- Buttons should be large and thumb-friendly (48px+ height)
- WhatsApp and Google Maps icons optional but helpful for recognition
- Keep the flow straightforward — no extra features needed

---

## Design System Tokens (EcoHarmony)

| Element | Value |
|---------|-------|
| Primary Green | #0f5238 |
| Primary Container | #2d6a4f |
| Mint Light | #95d5b2 |
| Secondary Container | #b0f1cc |
| Surface (Background) | #f8f9fa |
| Surface Gray | #E9ECEF |
| On Surface (Text) | #191c1d |
| Error Red | #E63946 |
| Status Blue (Pending) | #457B9D |
| Headline Font | Plus Jakarta Sans (700 weight) |
| Body Font | Inter (400 weight) |
| Border Radius (Standard) | 0.5rem (8px) |
| Touch Target Height | 48px |
| Container Padding | 20px |
| Stack Gap (vertical spacing) | 16px |

---

## Accessibility & UX Notes

1. **Touch Targets**: All interactive elements (buttons, pins) should be at least 48px in height/width
2. **Color Contrast**: Use high contrast between text and backgrounds for readability
3. **Labels & Icons**: Use clear labels alongside icons (e.g., "Aceptar" + checkmark icon)
4. **Scrollability**: Support vertical scrolling on screens with long content
5. **Error States**: If a request expires or is taken by another picker, show a clear error message
6. **Loading States**: Show loading indicator while accepting a request (network call)

---

## Integration Notes

- **Map Integration**: Use native map API (Google Maps for Flutter) or a lightweight library
- **WhatsApp Integration**: Use deep linking to open WhatsApp (`https://wa.me/...` or Flutter plugin)
- **Google Maps Navigation**: Use intent/deep linking to open Google Maps with coordinates
- **Real-time Updates**: Consider WebSocket or polling for live request updates on the map
- **Permissions**: Request location permission on app launch (iOS & Android)

---

## Future Enhancements (Out of Scope for v0.1)

- Push notifications when new requests appear nearby
- Chat/messaging directly in the app (currently using WhatsApp)
- Real-time tracking of picker location for requester
- Rating/review system for pickers
- Earnings tracking and payout management
- In-app support/help documentation

---

## Summary

The picker flow is straightforward and focused on:
1. **Discovery** (Map View) — find nearby requests
2. **Evaluation** (Request Details) — review full details
3. **Confirmation** (Confirmation Dialog) — commit to accepting
4. **Navigation** (Post-Accept View) — go get it and mark done

All communication happens via WhatsApp or Google Maps — no in-app chat or complex navigation. Keep the design minimal, practical, and task-focused.

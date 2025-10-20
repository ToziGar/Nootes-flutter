# Manual Edge Creation - Visual Quick Start

## 🎯 Quick Guide: Create Connections Between Notes

### Step 1: Activate Link Mode
```
┌─────────────────────────────┐
│  Control Panel              │
│  (bottom-right corner)      │
│                             │
│  ☑ 🔗 Link Mode  ← Click!  │
│  (turns orange when active) │
└─────────────────────────────┘
```

---

### Step 2: Select Source Node
```
     Touch or click on
     the first note
           ↓
      ┌─────────┐
      │ Note A  │ ← Source
      │ (glows  │
      │ orange) │
      └─────────┘
```

---

### Step 3: Drag to Target Node
```
      ┌─────────┐
      │ Note A  │ ← Source (glowing)
      │ (glows) │
      └─────┬───┘
            │
            │  Orange dashed line
            │  with arrow → → →
            ↓
      ┌─────────┐
      │ Note B  │ ← Target (hover over)
      │         │
      └─────────┘
```

**Visual Feedback:**
- 🟧 Orange dashed line from source to cursor
- 🔶 Orange arrow at cursor position
- ⭕ Orange glow around source node

---

### Step 4: Release on Target Node
```
      ┌─────────┐
      │ Note A  │
      └─────┬───┘
            │
            │ Connection created!
            ↓
      ┌─────────┐
      │ Note B  │
      └─────────┘
            ↓
    ┌──────────────────────┐
    │  Edge Editor Dialog  │
    │                      │
    │  Type: [Semantic ▼]  │
    │  Strength: ●───────○ │
    │  Label: [optional]   │
    │                      │
    │  [Cancel]  [Save]    │
    └──────────────────────┘
```

---

### Step 5: Configure & Save
```
Dialog Options:

┌─────────────────────────────┐
│ Edge Type:                  │
│ • Reference (📚)            │
│ • Semantic (🧠)             │
│ • Temporal (⏰)             │
│ • Causal (🔗)               │
│ • Hierarchical (🏛️)         │
│ • Similar (≈)               │
│ • Contradictory (⚡)        │
└─────────────────────────────┘

┌─────────────────────────────┐
│ Strength: (0.0 - 1.0)       │
│ ●─────────────────○         │
│ Weak ←          → Strong    │
└─────────────────────────────┘

Click "Save" → Done! ✅
```

---

### Step 6: View New Connection
```
      ┌─────────┐
      │ Note A  │
      └─────┬───┘
            │
            │ New edge appears!
            ↓ (with your settings)
      ┌─────────┐
      │ Note B  │
      └─────────┘

Success message:
┌──────────────────────────────┐
│ ✅ Enlace creado exitosamente│
└──────────────────────────────┘
```

---

## 🚫 What Happens If...

### Case 1: Release on Same Note (Self-Link)
```
      ┌─────────┐
      │ Note A  │ ← Drag back to same note
      └─────────┘
            ↓
      Nothing happens
      (dialog doesn't open)
      State resets automatically
```

### Case 2: Connection Already Exists
```
      ┌─────────┐
      │ Note A  │
      └─────┬───┘
            │ Already connected!
            ↓
      ┌─────────┐
      │ Note B  │
      └─────────┘
            ↓
    ┌──────────────────────────────┐
    │ ❌ Ya existe un enlace entre  │
    │    estas notas               │
    └──────────────────────────────┘
```

### Case 3: Release on Empty Space
```
      ┌─────────┐
      │ Note A  │
      └─────┬───┘
            │
            │ → → → (release)
            
      (empty space)
            ↓
      Nothing happens
      State resets automatically
```

---

## 🎨 Visual Indicators

### Link Mode OFF (Default)
```
Control Panel:
┌─────────────────────────┐
│ ☐ 🔗 Link Mode          │ ← Gray/white
│   (normal text)         │
└─────────────────────────┘

Actions:
• Drag nodes to reposition
• Pan graph with touch/mouse
• Zoom with pinch/wheel
```

### Link Mode ON (Active)
```
Control Panel:
┌─────────────────────────┐
│ ☑ 🔗 Link Mode          │ ← Orange
│   (bold text)           │
└─────────────────────────┘

Actions:
• Drag between nodes to link
• Pan/zoom disabled during drag
• Visual feedback appears
```

---

## 🎮 Interaction Flow Diagram

```
START
  │
  ▼
[ Enable Link Mode ] ──────┐
  │                        │
  ▼                        │
[ Touch Source Node ]      │
  │                        │
  ▼                        │
[ Visual Feedback Starts ] │
  │                        │
  │ • Dashed line          │
  │ • Arrow at cursor      │
  │ • Source glows         │
  │                        │
  ▼                        │
[ Drag to Target ]         │
  │                        │
  ▼                        │
[ Release ]                │
  │                        │
  ├─────────┬─────────┬────┤
  │         │         │    │
  ▼         ▼         ▼    │
[Target  [Same    [Empty   │
 Found]   Node]    Space]  │
  │         │         │    │
  │         ▼         ▼    │
  │      [Reset]  [Reset]  │
  │                        │
  ▼                        │
[ Check Existing Edge ]    │
  │                        │
  ├─────────┬──────────────┤
  │         │              │
  ▼         ▼              │
[Exists] [New Edge]        │
  │         │              │
  ▼         ▼              │
[Error]  [Show Dialog]     │
  │         │              │
  │         ▼              │
  │    [ Configure ]       │
  │         │              │
  │         ▼              │
  │    [ Save ]            │
  │         │              │
  │         ▼              │
  │    [ Success! ]        │
  │         │              │
  └─────────┴──────────────┤
                           │
                           ▼
                   [ Disable Link Mode? ]
                           │
                           ├──Yes──> END
                           │
                           └──No───> [ Create Another Link ]
```

---

## 📱 Touch Gestures

### Desktop (Mouse)
```
1. Click source node
2. Hold and drag
3. Release on target
```

### Mobile (Touch)
```
1. Tap source node
2. Hold and drag finger
3. Release on target
```

### Tablet (Stylus)
```
1. Tap source node with stylus
2. Hold and drag
3. Release on target
```

---

## 🎯 Detection Zones

```
Node Detection Radius: 40px

    ╔═══════════════════╗
    ║                   ║
    ║   ┌─────────┐     ║
    ║   │  Node   │     ║  40px radius
    ║   └─────────┘     ║  (touch-friendly)
    ║                   ║
    ╚═══════════════════╝

If cursor is within this circle → Node detected!
```

---

## 🌈 Color Scheme

```
┌──────────────────────────────────┐
│ Link Mode Theme: ORANGE          │
├──────────────────────────────────┤
│ Checkbox:   ■ Orange (active)    │
│             □ Gray (inactive)    │
│                                  │
│ Label:      🔗 Orange (active)   │
│             🔗 White (inactive)  │
│                                  │
│ Line:       ──── Orange @ 70%    │
│ Arrow:      ▶ Solid Orange       │
│ Glow:       ⭕ Orange @ 30%      │
└──────────────────────────────────┘
```

---

## ⚡ Quick Tips

### Tip 1: Cancel Anytime
```
To cancel during drag:
• Release on empty space
• Or toggle link mode off
• State resets automatically
```

### Tip 2: Switch Modes
```
Toggle checkbox to switch:
• ON  → Create links
• OFF → Drag nodes, pan, zoom
```

### Tip 3: Edit Existing Edges
```
To modify created links:
1. Long-press on edge line
2. Select "Edit" from context menu
3. Change properties
4. Save or delete
```

### Tip 4: View All Connections
```
Use Edge Filter Panel:
• Show/hide by type
• Adjust strength threshold
• See connection stats
```

---

## 🎬 Example Use Cases

### Use Case 1: Reference Connection
```
📚 Paper A ──reference──> 📚 Paper B
   (cites)                  (cited by)
```

### Use Case 2: Semantic Link
```
🧠 Concept A ──semantic──> 🧠 Concept B
   (related to)             (related to)
```

### Use Case 3: Temporal Sequence
```
⏰ Event A ──temporal──> ⏰ Event B
   (before)               (after)
```

### Use Case 4: Hierarchical Structure
```
🏛️ Parent ──hierarchical──> 🏛️ Child
   (contains)                 (part of)
```

---

## 📊 Before & After

### Before Manual Edges
```
Notes in graph:
• Only AI-detected connections
• Limited relationship types
• No user customization

         [AI]
          │
          ▼
   Automatic edges only
```

### After Manual Edges
```
Notes in graph:
• AI connections (automatic)
• User connections (manual)
• Rich relationship types
• Full customization

    [AI] + [User]
          │
          ▼
   Combined knowledge graph
```

---

## ✅ Success Checklist

- [ ] Enable link mode (checkbox turns orange)
- [ ] Touch source node (node glows orange)
- [ ] Drag to target (see dashed line and arrow)
- [ ] Release on target (dialog appears)
- [ ] Configure edge properties
- [ ] Save edge (success toast appears)
- [ ] See new connection in graph
- [ ] Disable link mode (return to normal)

---

## 🏆 You're Ready!

**Congratulations!** You now know how to create manual connections between notes in the interactive graph.

**Try it out:**
1. Open your Nootes app
2. Go to graph view
3. Enable 🔗 Link Mode
4. Create your first connection!

**Have fun building your knowledge graph!** 🎉

---

**Quick Reference Card**

```
┌────────────────────────────────────────┐
│ MANUAL EDGE CREATION CHEAT SHEET      │
├────────────────────────────────────────┤
│ Enable:  ☑ Link Mode checkbox         │
│ Start:   Touch source node             │
│ Visual:  Orange line + arrow           │
│ Finish:  Release on target node        │
│ Config:  Set type, strength, label     │
│ Save:    Click save button             │
│ Result:  New edge appears in graph     │
│ Cancel:  Release on empty space        │
│ Disable: ☐ Link Mode checkbox         │
└────────────────────────────────────────┘
```

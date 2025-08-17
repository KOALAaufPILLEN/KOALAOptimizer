# Enhanced UAC and Visual Effects Features

## 🔐 Enhanced Admin Elevation (UAC) Features

### What's New
The KOALA Gaming Optimizer now includes intelligent UAC (User Account Control) handling that provides a much better user experience for privilege management.

### Key Improvements

#### 1. **Smart Privilege Detection**
- Automatically detects current privilege level at startup
- Clearly shows what features are available vs. require admin
- Provides detailed feedback about missing permissions

#### 2. **Automatic Elevation Options** 
- When admin rights are needed, users get three choices:
  - **Yes**: Automatically restart with admin privileges
  - **No**: Continue with limited functionality (user-level optimizations only)
  - **Cancel**: Exit the application

#### 3. **Graceful Fallback**
- No longer fails completely if not running as admin
- User-level optimizations (visual effects, Game DVR, etc.) still work
- Clear warnings about which optimizations are skipped

#### 4. **Operation Categories**
Operations are now categorized by admin requirements:

**Requires Admin:**
- System registry modifications (HKEY_LOCAL_MACHINE)
- Windows service configuration
- Power plan and hibernation settings
- Memory management optimizations
- Network stack modifications

**Works Without Admin:**
- User registry changes (HKEY_CURRENT_USER)
- Visual effects optimization
- Game DVR settings
- Process priority adjustment (limited)
- Fullscreen optimizations

### Usage Examples

#### Startup Messages
```
✓ Running with Administrator privileges - All optimizations available
```
or
```
⚠ Limited mode - Available: Visual Effects, Game DVR Settings | Requires Admin: Memory Management, Power Settings
💡 Tip: For full functionality, restart as Administrator or click 'Apply Selected' for elevation prompt
```

## 🎨 Selective Visual Effects Optimization

### What Changed
The old "Disable Visual Effects" option has been completely reimplemented to provide a much more balanced approach.

### Previous Behavior
- Used `VisualFXSetting = 2` (Adjust for best performance)
- Disabled ALL visual effects including functional elements
- Made Windows look very basic and dated
- Users generally disliked the appearance

### New Selective Approach

#### **Performance Elements Disabled:**
- ✅ Window animations (open/close/minimize/maximize)
- ✅ Menu fade and slide animations  
- ✅ Taskbar thumbnail previews (Aero Peek)
- ✅ Fade effects for menus and tooltips
- ✅ Desktop composition effects (reduced GPU load)
- ✅ Thumbnail caching optimizations

#### **Functional Elements Preserved:**
- ✅ Window borders and basic styling
- ✅ Font smoothing for readability
- ✅ System icons and taskbar functionality
- ✅ File explorer basic theming
- ✅ Control panel visual layout
- ✅ Full window dragging (contents visible while dragging)

### Technical Implementation

The new system uses a custom `UserPreferencesMask` binary value that selectively enables/disables specific visual elements rather than using the broad "best performance" setting.

**Registry changes made:**
```powershell
# Custom mode for fine control
HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\VisualFXSetting = 3

# Disable performance-impacting animations
HKCU:\Control Panel\Desktop\MinAnimate = "0"
HKCU:\Control Panel\Desktop\MenuShowDelay = "0"
HKCU:\Software\Microsoft\Windows\DWM\EnableAeroPeek = 0

# Preserve functional elements
HKCU:\Control Panel\Desktop\DragFullWindows = "1"
HKCU:\Control Panel\Desktop\FontSmoothing = "2"
HKCU:\Control Panel\Desktop\FontSmoothingType = 2
```

### Benefits

1. **Better Gaming Performance**: Eliminates GPU-intensive effects and animations
2. **Maintained Usability**: Keeps Windows looking modern and functional
3. **User Satisfaction**: Balances performance with visual appeal
4. **Reversible**: Can be completely reverted to system defaults

### Comparison

| Feature | Old Method | New Selective Method |
|---------|------------|---------------------|
| Window Animations | ❌ Disabled | ❌ Disabled |
| Window Borders | ❌ Basic/Ugly | ✅ Modern/Clean |
| Font Smoothing | ❌ Disabled | ✅ Enabled |
| Taskbar Previews | ❌ Disabled | ❌ Disabled (Performance) |
| File Explorer | ❌ Very Basic | ✅ Functional Theme |
| User Satisfaction | 😞 Poor | 😊 Good |
| Performance Impact | 🚀 Maximum | 🚀 Near-Maximum |

## 🚀 Usage Instructions

### For Regular Users
1. **Just run the script** - it will automatically detect your privilege level
2. **If prompted for elevation** - choose "Yes" for full functionality
3. **Select "Selective Visual Effects Optimization"** instead of the old disable option
4. **Apply and enjoy** better performance without sacrificing too much visual appeal

### For Advanced Users
- The `KOALA_Launcher.bat` provides a command-line interface for UAC handling
- Visual effects can be manually reverted using the "Revert All" function
- Individual registry keys can be modified if you want different visual balance

## 🔧 Technical Notes

### Admin Privilege Functions
- `Test-AdminPrivileges()` - Check current privilege level
- `Request-AdminElevation()` - Attempt automatic elevation
- `Get-AdminRequiredOperations()` - Categorize operations by requirements
- `Get-AdminStatusMessage()` - User-friendly status messaging

### Visual Effects Functions  
- `Set-SelectiveVisualEffects -EnablePerformanceMode` - Apply optimizations
- `Set-SelectiveVisualEffects -Revert` - Restore defaults

This implementation provides the best of both worlds: maximum gaming performance where it matters, while keeping Windows looking and feeling modern and functional.
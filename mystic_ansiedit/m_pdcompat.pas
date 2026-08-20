Unit m_pdcompat;

// ====================================================================
// PabloDraw DOS/32-bit Compatibility Layer
//
// On 32-bit (Linux, Windows, GO32V2): uses class/Create/Destroy/Free
// On 16-bit DOS (i8086-msdos): uses object/Init/Done
//
// Include this unit and use the PD_CLASS/PD_CONSTRUCTOR/PD_DESTRUCTOR
// macros in m_pd* units.
// ====================================================================

{$I M_OPS.PAS}

Interface

{$IFDEF MSDOS}
  { 16-bit DOS: no class support, use object }
  {$DEFINE PD_USE_OBJECT}
{$ENDIF}

Implementation

End.

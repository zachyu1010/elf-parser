/*======================================================================*/
/* Default maven linker script                                          */
/*======================================================================*/
/* This is the default linker script for maven. It is based off of the
   mips idt32.ld linker script. I have added many more comments and
   tried to clean things up a bit. For more information about standard
   MIPS sections see Section 9.5 of "See MIPS Run Linux" by Dominic
   Sweetman. For more generic information about the init, fini, ctors,
   and dtors sections see the paper titled "ELF From the Programmers
   Perspective" by Hongiu Lu. */

/*----------------------------------------------------------------------*/
/* Setup                                                                */
/*----------------------------------------------------------------------*/

/* The ENTRY command specifies the entry point (ie. first instruction to
   execute). The symbol _start is defined in crt0.S */

ENTRY( _start )
MEMORY
{
    /* FLASH (xr)  : ORIGIN = 0x08000000, LENGTH = 512K */
    DRAM (xrw)   : ORIGIN = 0x10000000, LENGTH = 32M
    HEAP (rw)    : ORIGIN = 0x12000000, LENGTH = 192M
    STACK (rw)   : ORIGIN = 0x1E000000, LENGTH = 16M
    STDOUT (rw)  : ORIGIN = 0x1F000000, LENGTH = 16M    
    UDRAM (rw)   : ORIGIN = 0x20000000, LENGTH = 3584M    
    /* CCM (rw)    : ORIGIN = 0x10000000, LENGTH = 64K */
}
/*----------------------------------------------------------------------*/
/* Sections                                                             */
/*----------------------------------------------------------------------*/
/* This is where we specify how the input sections map to output
   sections. The .= commands set the location counter, and the
   sections are inserted in increasing address order according to the
   location counter. The following statement will take all of the .bar
   input sections and reloate them into the .foo output section which
   starts at address 0x1000.

    . = 0.x1000;
    .foo : { *(.bar) }

   If we wrap an input specification with a KEEP command then it
   prevents it from being eliminted during "link-time garbage
   collection". I'm not sure what this is, so I just followed what was
   done in idt32.ld.

   We can also set a global external symbol to a specific address in the
   output binary with this syntax:

    _etext = .;
    PROVIDE( etext = . );

   This will set the global symbol _ftext to the current location. If we
   wrap this in a PROVIDE commad, the symbol will only be set if it is
   not defined. We do this with symbols which don't begin with an
   underscore since technically in ansi C someone might have a function
   with the same name (eg. etext).

   If we need to label the beginning of a section we need to make sure
   that the linker doesn't insert an orphan section inbetween where we
   set the symbol and the actual begining of the section. We can do that
   by assigning the location dot to itself.

    . = .
    _ftext = .;
    .text :
    { }

   */

SECTIONS
{

  /*--------------------------------------------------------------------*/
  /* Code and read-only segment                                         */
  /*--------------------------------------------------------------------*/
  
  /* Begining of code and text segment */

  .entry :
  {
      KEEP(*(.entry))     /*  Keep entry here. */
  } > DRAM

  .text : 
  {
    *(.text)
    *(.text.*)
    *(.gnu.linkonce.t.*)
  } > DRAM
  
  _ftext = .;
  PROVIDE( eprol = . );
  /* rodata: Read-only data */
  .rodata : 
  {
    *(.rdata)
    *(.rodata)
    *(.rodata.*)
    *(.gnu.linkonce.r.*)
  } > DRAM

  /* End of code and read-only segment */
  PROVIDE( etext = . );
  _etext = .;

  /*--------------------------------------------------------------------*/
  /* Global constructor/destructor segement                             */
  /*--------------------------------------------------------------------*/

  .preinit_array     :
  {
    PROVIDE_HIDDEN (__preinit_array_start = .);
    KEEP (*(.preinit_array))
    PROVIDE_HIDDEN (__preinit_array_end = .);
  } > DRAM

  .init_array     :
  {
    PROVIDE_HIDDEN (__init_array_start = .);
    KEEP (*(SORT(.init_array.*)))
    KEEP (*(.init_array ))
    PROVIDE_HIDDEN (__init_array_end = .);
  } > DRAM

  .fini_array     :
  {
    PROVIDE_HIDDEN (__fini_array_start = .);
    KEEP (*(SORT(.fini_array.*)))
    KEEP (*(.fini_array ))
    PROVIDE_HIDDEN (__fini_array_end = .);
  } > DRAM

  /*--------------------------------------------------------------------*/
  /* Initialized data segment                                           */
  /*--------------------------------------------------------------------*/

  /* Start of initialized data segment */
  . = ALIGN(32);
   _fdata = .;

  /* data: Writable data */
  .data : 
  {
    *(.data)
    *(.data.*)
    *(.gnu.linkonce.d.*)
  } > DRAM

  /* End of initialized data segment */
  PROVIDE( edata = . );
  _edata = .;



    /* Writable small data segment */
  .sdata : 
  {
    /* Have _gp point to middle of sdata/sbss to maximize displacement range */
    . = ALIGN(32);
    /* _gp = . + 0x800; */
    /* PROVIDE( __global_pointer$ = . + 0x00000800 ); */
    *(.sdata)
    *(.sdata.*)
    *(.srodata.*)
    *(.gnu.linkonce.s.*)
  } > DRAM

  /*--------------------------------------------------------------------*/
  /* Uninitialized data segment                                         */
  /*--------------------------------------------------------------------*/

  /* Start of uninitialized data segment */
  . = ALIGN(32);
  _fbss = .;

  /* Writable uninitialized small data segment */
  .sbss : 
  {
    *(.sbss)
    *(.sbss.*)
    *(.gnu.linkonce.sb.*)
  } > DRAM

  /* bss: Uninitialized writeable data section */
  . = .;
  _bss_start = .;
  .bss : 
  {
    *(.bss)
    *(.bss.*)
    *(.gnu.linkonce.b.*)
    *(COMMON)
  } > DRAM
  /* heap for malloc */
  .heap :{
    KEEP(*(.heap))
    PROVIDE( __heap_start = .);
    PROVIDE( __global_pointer$ = .); /* Need to add core id offset in crt0. */
    PROVIDE(__heap_end = ORIGIN(HEAP) + LENGTH(HEAP));
  } > HEAP

  .stack :{
    KEEP(*(.stack))
    PROVIDE( stack_magickey = .);
    PROVIDE(__stack_pointer$ = ORIGIN(STACK) + LENGTH(STACK) - 64);
  } > STACK

  .stdout :{
    KEEP(*(.stdout))
    PROVIDE( __stdout_cursor = ORIGIN(STDOUT));
    /*
    typedef struct {
      void *buffer;
      int head;
      int tail;
      int maxSize;
    } KprintBuffer;
    */
    PROVIDE( __stdout_start = ORIGIN(STDOUT)+16); /* 16=sizeof(KprintBuffer) */
    PROVIDE( __stdout_end = ORIGIN(STDOUT) + LENGTH(STDOUT));

  } > STDOUT

  /* End of uninitialized data segment (used by syscalls.c for heap) */
  PROVIDE( end = . );
  _end = ALIGN(32);

}

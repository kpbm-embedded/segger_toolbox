/* jlinkscript_api.h: declarations of the J-Link script file API, only for a host syntax check
 * (`arm-none-eabi-gcc -x c -fsyntax-only -include jlinkscript_api.h x.JLinkScript`). J-Link interprets
 * .JLinkScript files itself; this header is not SEGGER's and holds no implementation.
 * Names from https://kb.segger.com/J-Link_Script_Files (functions and global variables used in this ID). */
#ifndef JLINKSCRIPT_API_H
#define JLINKSCRIPT_API_H
#define __constant const    /* SEGGER scripts declare constants as `__constant U32 _NAME = value;` */
typedef unsigned int U32;
typedef unsigned short U16;
typedef unsigned char U8;
typedef int I32;
/* system */
void JLINK_SYS_Report(const char *sMsg);
void JLINK_SYS_Report1(const char *sMsg, U32 Value);
void JLINK_SYS_Sleep(int Delayms);
U32  JLINK_GetTime(void);
int  JLINK_ExecCommand(const char *sCmd);
/* target memory */
U32  JLINK_MEM_ReadU32(U32 Addr);
U16  JLINK_MEM_ReadU16(U32 Addr);
U8   JLINK_MEM_ReadU8(U32 Addr);
int  JLINK_MEM_WriteU32(U32 Addr, U32 Data);
int  JLINK_MEM_WriteU16(U32 Addr, U32 Data);
int  JLINK_MEM_WriteU8(U32 Addr, U32 Data);
/* target control */
int  JLINK_TARGET_Halt(void);
int  JLINK_TARGET_IsHalted(void);
/* CoreSight / debug port */
int  JLINK_CORESIGHT_Configure(const char *sConfig);
int  JLINK_CORESIGHT_AddAP(int Index, U32 Type);
int  JLINK_CORESIGHT_ReadAP(int RegIndex);
int  JLINK_CORESIGHT_ReadDP(int RegIndex);
int  JLINK_CORESIGHT_WriteAP(int RegIndex, U32 Data);
int  JLINK_CORESIGHT_WriteDP(int RegIndex, U32 Data);
int  JLINK_CORESIGHT_ReadDAP(int RegIndex, int APnDP, U32 *Data);
int  JLINK_CORESIGHT_WriteDAP(int RegIndex, int APnDP, U32 Data);
/* global variables a script may set */
extern U32 CPU;
extern U32 JTAG_AllowTAPReset;
extern U32 CORESIGHT_CoreBaseAddr;
extern U32 CORESIGHT_IndexAHBAPToUse;
extern U32 MAIN_ResetType;
/* constants */
enum { CORTEX_M0 = 1, CORTEX_M3, CORTEX_M4, CORTEX_M7, CORTEX_M33, ARM_AP_TYPE_AHB = 1, ARM_AP_TYPE_APB };
/* hook functions J-Link calls when a script defines them */
int  ConfigTargetSettings(void);
int  InitTarget(void);
int  SetupTarget(void);
int  ResetTarget(void);
int  AfterResetTarget(void);
int  InitEMU(void);
int  HandleBeforeFlashProg(void);
int  HandleAfterFlashProg(void);
#endif

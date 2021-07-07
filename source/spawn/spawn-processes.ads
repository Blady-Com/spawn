------------------------------------------------------------------------------
--                         Language Server Protocol                         --
--                                                                          --
--                     Copyright (C) 2018-2021, AdaCore                     --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
------------------------------------------------------------------------------

--  Asynchronous API with listener pattern

with Ada.Exceptions;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Interfaces;

with Spawn.Environments;
with Spawn.String_Vectors;

private with Spawn.Internal;

package Spawn.Processes is

   type Process_Exit_Status is (Normal, Crash);

   type Process_Exit_Code is new Interfaces.Unsigned_32;

   type Process_Listener is limited interface;
   type Process_Listener_Access is access all Process_Listener'Class;

   procedure Standard_Output_Available
    (Self : in out Process_Listener) is null;
   --  Called once when it's possible to read data again.

   procedure Standard_Error_Available
    (Self : in out Process_Listener) is null;
   --  Called once when it's possible to read data again.

   procedure Standard_Input_Available
    (Self : in out Process_Listener) is null;
   --  Called once when it's possible to write data again.

   procedure Started (Self : in out Process_Listener) is null;

   procedure Finished
    (Self        : in out Process_Listener;
     Exit_Status : Process_Exit_Status;
     Exit_Code   : Process_Exit_Code) is null;
   --  Called when the process finishes. Exit_Status is exit status of the
   --  process. On normal exit, Exit_Code is the exit code of the process,
   --  on crash its meaning depends from operating system. For POSIX systems
   --  it is number of signal when available, on Windows it is process exit
   --  code.

   procedure Error_Occurred
    (Self          : in out Process_Listener;
     Process_Error : Integer) is null;

   procedure Exception_Occurred
     (Self       : in out Process_Listener;
      Occurrence : Ada.Exceptions.Exception_Occurrence) is null;
   --  This will be called when an exception occurred in one of the
   --  callbacks set in place

   type Process_Error is (Failed_To_Start);

   type Process_Status is
    (Not_Running,
     Starting,
     Running);

   type Process is tagged limited private;

   function Arguments (Self : Process'Class)
     return Spawn.String_Vectors.UTF_8_String_Vector;
   procedure Set_Arguments
     (Self      : in out Process'Class;
      Arguments : Spawn.String_Vectors.UTF_8_String_Vector)
        with Pre => Self.Status = Not_Running;
   --  Command line arguments

   function Environment (Self : Process'Class)
     return Spawn.Environments.Process_Environment;

   procedure Set_Environment
     (Self        : in out Process'Class;
      Environment : Spawn.Environments.Process_Environment)
        with Pre => Self.Status = Not_Running;
   --  Process environment

   function Working_Directory (Self : Process'Class) return UTF_8_String;
   procedure Set_Working_Directory
     (Self      : in out Process'Class;
      Directory : UTF_8_String)
        with Pre => Self.Status = Not_Running;
   --  Working directory

   function Program (Self : Process'Class) return UTF_8_String;
   procedure Set_Program
     (Self    : in out Process'Class;
      Program : UTF_8_String)
        with Pre => Self.Status = Not_Running;
   --  Executables name

   procedure Start (Self : in out Process'Class)
     with Pre => Self.Status = Not_Running;

   function Status (Self : Process'Class) return Process_Status;

   function Exit_Status (Self : Process'Class) return Process_Exit_Status
     with Pre => Self.Status = Not_Running;
   --  Return the exit status of last process that finishes.

   function Exit_Code (Self : Process'Class) return Process_Exit_Code
     with Pre => Self.Status = Not_Running;
   --  Return the exit code of last process that finishes when exit status is
   --  Normal, or signal number (on POSIX systems) or exit code (on Windows).

   procedure Terminate_Process (Self : in out Process'Class);
   --  Ask process to exit. Process can ignore this request.
   --
   --  On Windows, WM_CLOSE message are post, and on POSIX, the SIGTERM signal
   --  is sent.

   procedure Kill_Process (Self : in out Process'Class);
   --  Kill current process. Process will exit immediately.
   --
   --  On Windows, TerminateProcess() is called, and on POSIX, the SIGKILL
   --  signal is sent.

   function Listener (Self : Process'Class) return Process_Listener_Access;
   procedure Set_Listener
     (Self     : in out Process'Class;
      Listener : Process_Listener_Access)
        with Pre => Self.Status = Not_Running;
   --  Process's events listener

   procedure Close_Standard_Input (Self : in out Process'Class);
   --  Do nothing if Self.Status /= Running

   procedure Write_Standard_Input
     (Self : in out Process'Class;
      Data : Ada.Streams.Stream_Element_Array;
      Last : out Ada.Streams.Stream_Element_Offset);
   --  Do nothing if Self.Status /= Running. Last is set to index of the last
   --  element to be written. If Last < Data'Last it means incomplete
   --  operation, Standard_Input_Available notification will be called once
   --  operation can be continued. Application is responsible to call this
   --  subprogram again for remaining data.

   procedure Close_Standard_Output (Self : in out Process'Class);
   --  Do nothing if Self.Status /= Running

   procedure Read_Standard_Output
     (Self : in out Process'Class;
      Data : out Ada.Streams.Stream_Element_Array;
      Last : out Ada.Streams.Stream_Element_Offset);
   --  Returns available data received throgh standard output stream. If no
   --  data was read you will get Standard_Output_Available notification latter

   procedure Close_Standard_Error (Self : in out Process'Class);
   --  Do nothing if Self.Status /= Running

   procedure Read_Standard_Error
     (Self : in out Process'Class;
      Data : out Ada.Streams.Stream_Element_Array;
      Last : out Ada.Streams.Stream_Element_Offset);

   function Wait_For_Started
     (Self    : in out Process'Class;
      Timeout : Duration := Duration'Last) return Boolean;
   --  Block until process has started or until Timeout have passed. Return
   --  True when process has been started successfully.
   --
   --  Started subprogram of the listener is called before exit from this
   --  subprogram.

   function Wait_For_Finished
     (Self    : in out Process'Class;
      Timeout : Duration := Duration'Last) return Boolean;
   --  Block until process has been finished ot until Timeout have passed.
   --  Return True when process has finished.
   --
   --  Finished subprogram of the listener is called before exit from this
   --  subprogram.

   function Wait_For_Standard_Input_Available
     (Self    : in out Process'Class;
      Timeout : Duration := Duration'Last) return Boolean;
   --  Block until standard input is available for write.
   --
   --  Standard_Input_Available subprogram of the listener is called before
   --  exit from this subprogram.

   function Wait_For_Standard_Output_Available
     (Self    : in out Process'Class;
      Timeout : Duration := Duration'Last) return Boolean;
   --  Block until standard output has data available for read.
   --
   --  Standard_Output_Available subprogram of the listener is called before
   --  exit from this subprogram.

   function Wait_For_Standard_Error_Available
     (Self    : in out Process'Class;
      Timeout : Duration := Duration'Last) return Boolean;
   --  Block until standard error has data available for read.
   --
   --  Standard_Error_Available subprogram of the listener is called before
   --  exit from this subprogram.

private

   use all type Internal.Pipe_Kinds;
   subtype Pipe_Kinds is Internal.Pipe_Kinds;
   subtype Standard_Pipe is Pipe_Kinds range Stdin .. Stderr;

   type Process is new Spawn.Internal.Process with record
      Arguments   : Spawn.String_Vectors.UTF_8_String_Vector;
      Environment : Spawn.Environments.Process_Environment :=
        Spawn.Environments.System_Environment;
      Exit_Status : Process_Exit_Status := Normal;
      Exit_Code   : Process_Exit_Code := Process_Exit_Code'Last;
      Status      : Process_Status := Not_Running;
      Listener    : Process_Listener_Access;
      Program     : Ada.Strings.Unbounded.Unbounded_String;
      Directory   : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   overriding procedure Finalize (Self : in out Process);

end Spawn.Processes;

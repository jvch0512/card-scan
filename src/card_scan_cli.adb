with Ada.Command_Line;        use Ada.Command_Line;
with Ada.Containers.Vectors;
with Ada.Directories;         use Ada.Directories;
with Ada.Strings.Unbounded;   use Ada.Strings.Unbounded;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;             use Ada.Text_IO;
with Ada.Text_IO.Unbounded_IO;
with Ada.Exceptions;
with Card_Scan;               use Card_Scan;

procedure Card_Scan_Cli is

   type Severity is (High, Low, Info);

   type Finding is record
      Sev    : Severity;
      Rule   : Unbounded_String;
      File   : Unbounded_String;
      Line   : Natural;
      Column : Positive;
      Text   : Unbounded_String;
   end record;

   package Finding_Vectors is new Ada.Containers.Vectors (Positive, Finding);
   use Finding_Vectors;

   function Before (A, B : Finding) return Boolean is
   begin
      if A.File /= B.File then
         return A.File < B.File;
      elsif A.Line /= B.Line then
         return A.Line < B.Line;
      else
         return A.Column < B.Column;
      end if;
   end Before;

   package Sorting is new Finding_Vectors.Generic_Sorting ("<" => Before);

   Findings   : Vector;
   Files_Seen : Natural := 0;
   Skipped    : Natural := 0;
   Tsv        : Boolean := False;
   Fail_High  : Boolean := False;
   Fail_Any   : Boolean := False;
   Target     : Unbounded_String;
   Max_Size   : constant := 5 * 1024 * 1024;

   procedure Usage is
   begin
      Put_Line (Standard_Error,
                "usage: card-scan PATH [--tsv] [--fail-on high|any]");
      Put_Line (Standard_Error,
                "Exit: 0 ok, 1 findings at or above --fail-on, 2 bad input.");
      Set_Exit_Status (2);
   end Usage;

   function Is_Binary (Path : String) return Boolean is
      use Ada.Streams;
      F    : Stream_IO.File_Type;
      Buf  : Stream_Element_Array (1 .. 4096);
      Last : Stream_Element_Offset;
   begin
      Stream_IO.Open (F, Stream_IO.In_File, Path);
      Stream_IO.Read (F, Buf, Last);
      Stream_IO.Close (F);
      for I in 1 .. Last loop
         if Buf (I) = 0 then
            return True;
         end if;
      end loop;
      return False;
   end Is_Binary;

   procedure Add (Sev : Severity; Rule, File : String; Line : Natural;
                  Col : Positive; Text : String) is
   begin
      Findings.Append ((Sev, To_Unbounded_String (Rule),
                        To_Unbounded_String (File), Line, Col,
                        To_Unbounded_String (Text)));
   end Add;

   procedure Scan_File (Path : String) is
      F     : File_Type;
      N     : Natural := 0;
      Found : Match_Array (1 .. Max_Matches);
      Count : Natural;
   begin
      if Size (Path) > Max_Size or else Is_Binary (Path) then
         Skipped := Skipped + 1;
         return;
      end if;
      Files_Seen := Files_Seen + 1;
      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         declare
            L : constant String := To_String (Ada.Text_IO.Unbounded_IO.Get_Line (F));
         begin
            N := N + 1;
            Scan_Line (L, Found, Count);
            for K in 1 .. Count loop
               declare
                  M : Match renames Found (K);
                  D : constant String := M.Masked (1 .. M.Number_Len);
                  Len : constant String := Natural'Image (M.Number_Len);
                  Desc : constant String :=
                    Brand_Name (M.Kind) & " " & D & " (" &
                    Len (Len'First + 1 .. Len'Last) & " digits)";
               begin
                  if M.Is_Test then
                     Add (Info, "CARD003", Path, N, M.Column,
                          "public test card number: " & Desc);
                  elsif M.Kind /= Unknown then
                     Add (High, "CARD001", Path, N, M.Column,
                          "card number: " & Desc);
                  else
                     Add (Low, "CARD002", Path, N, M.Column,
                          "Luhn-valid number, unknown issuer: " & D);
                  end if;
               end;
            end loop;
         end;
      end loop;
      Close (F);
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
         Skipped := Skipped + 1;
   end Scan_File;

   procedure Walk (Dir : String) is
      S : Search_Type;
      E : Directory_Entry_Type;
   begin
      Start_Search (S, Dir, "",
                    (Ordinary_File | Directory => True, others => False));
      while More_Entries (S) loop
         Get_Next_Entry (S, E);
         declare
            Name : constant String := Simple_Name (E);
            Full : constant String := Compose (Dir, Name);
         begin
            if Name = "." or else Name = ".." or else Name = ".git" then
               null;
            elsif Kind (E) = Directory then
               Walk (Full);
            else
               Scan_File (Full);
            end if;
         end;
      end loop;
      End_Search (S);
   exception
      when others => Skipped := Skipped + 1;
   end Walk;

   function Sev_Name (S : Severity) return String is
   begin
      case S is
         when High => return "high";
         when Low  => return "low";
         when Info => return "info";
      end case;
   end Sev_Name;

   function Upper (S : String) return String is
      R : String := S;
   begin
      for C of R loop
         if C in 'a' .. 'z' then
            C := Character'Val (Character'Pos (C) - 32);
         end if;
      end loop;
      return R;
   end Upper;

   function Img (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (S'First + 1 .. S'Last);
   end Img;

   Have_Target : Boolean := False;
   Bad_Args    : Boolean := False;
   I           : Positive := 1;
begin
   while I <= Argument_Count loop
      declare
         A : constant String := Argument (I);
      begin
         if A = "--tsv" then
            Tsv := True;
         elsif A = "--fail-on" and then I < Argument_Count then
            I := I + 1;
            if Argument (I) = "high" then
               Fail_High := True;
            elsif Argument (I) = "any" then
               Fail_Any := True;
            else
               Bad_Args := True;
            end if;
         elsif A'Length > 0 and then A (A'First) = '-' then
            Bad_Args := True;
         elsif Have_Target then
            Bad_Args := True;
         else
            Target := To_Unbounded_String (A);
            Have_Target := True;
         end if;
      end;
      I := I + 1;
   end loop;

   if Bad_Args or else not Have_Target then
      Usage;
      return;
   end if;

   declare
      T : constant String := To_String (Target);
   begin
      if not Exists (T) then
         Put_Line (Standard_Error, "error: no such file or directory: " & T);
         Set_Exit_Status (2);
         return;
      end if;
      if Kind (T) = Directory then
         Walk (T);
      else
         Scan_File (T);
      end if;
   end;

   Sorting.Sort (Findings);

   declare
      Summary : constant String :=
        Img (Files_Seen) & " files scanned, " & Img (Natural (Findings.Length)) &
        " findings" & (if Skipped > 0 then ", " & Img (Skipped) & " skipped" else "");
      Any_High : Boolean := False;
   begin
      if Tsv then
         Put_Line ("# " & Summary);
      else
         Put_Line (Summary);
      end if;
      for F of Findings loop
         if F.Sev = High then
            Any_High := True;
         end if;
         if Tsv then
            Put_Line (Sev_Name (F.Sev) & ASCII.HT & To_String (F.Rule) & ASCII.HT &
                      To_String (F.File) & ":" & Img (F.Line) & ASCII.HT &
                      To_String (F.Text));
         else
            Put_Line (Upper (Sev_Name (F.Sev)) & "  " & To_String (F.Rule) & " " &
                      To_String (F.File) & ":" & Img (F.Line));
            Put_Line ("          " & To_String (F.Text));
         end if;
      end loop;
      if (Fail_High and then Any_High) or else (Fail_Any and then not Findings.Is_Empty) then
         Set_Exit_Status (1);
      end if;
   end;
exception
   when E : others =>
      Put_Line (Standard_Error, "error: " & Ada.Exceptions.Exception_Message (E));
      Set_Exit_Status (2);
end Card_Scan_Cli;

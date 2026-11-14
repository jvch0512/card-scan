package body Card_Scan is

   function Is_Digit (C : Character) return Boolean is (C in '0' .. '9');

   function Luhn_Valid (Number : String) return Boolean is
      Sum    : Natural := 0;
      Double : Boolean := False;
      D      : Natural;
   begin
      if Number'Length = 0 then
         return False;
      end if;
      for I in reverse Number'Range loop
         if not Is_Digit (Number (I)) then
            return False;
         end if;
         D := Character'Pos (Number (I)) - Character'Pos ('0');
         if Double then
            D := D * 2;
            if D > 9 then
               D := D - 9;
            end if;
         end if;
         Sum := Sum + D;
         Double := not Double;
      end loop;
      return Sum mod 10 = 0;
   end Luhn_Valid;

   function Prefix (S : String; N : Positive) return Natural is
      V : Natural := 0;
   begin
      if S'Length < N then
         return 0;
      end if;
      for I in S'First .. S'First + N - 1 loop
         V := V * 10 + (Character'Pos (S (I)) - Character'Pos ('0'));
      end loop;
      return V;
   end Prefix;

   function Brand_Of (Number : String) return Brand is
      L  : constant Natural := Number'Length;
      P1 : constant Natural := Prefix (Number, 1);
      P2 : constant Natural := Prefix (Number, 2);
      P3 : constant Natural := Prefix (Number, 3);
      P4 : constant Natural := Prefix (Number, 4);
   begin
      if L < 13 or else L > 19 then
         return Unknown;
      end if;
      if P1 = 4 and then (L = 13 or else L = 16 or else L = 19) then
         return Visa;
      elsif ((P2 in 51 .. 55) or else (P4 in 2221 .. 2720)) and then L = 16 then
         return Mastercard;
      elsif (P2 = 34 or else P2 = 37) and then L = 15 then
         return Amex;
      elsif (P4 = 6011 or else P2 = 65 or else (P3 in 644 .. 649))
        and then L in 16 .. 19
      then
         return Discover;
      elsif ((P2 = 36 or else P2 = 38 or else P2 = 39) and then L in 14 .. 19)
        or else ((P3 in 300 .. 305) and then L in 14 .. 19)
      then
         return Diners;
      elsif (P4 in 3528 .. 3589) and then L in 16 .. 19 then
         return JCB;
      else
         return Unknown;
      end if;
   end Brand_Of;

   function Brand_Name (B : Brand) return String is
   begin
      case B is
         when Unknown    => return "Unknown";
         when Visa       => return "Visa";
         when Mastercard => return "Mastercard";
         when Amex       => return "American Express";
         when Discover   => return "Discover";
         when Diners     => return "Diners Club";
         when JCB        => return "JCB";
      end case;
   end Brand_Name;

   function Is_Test_Number (Number : String) return Boolean is
      type Str_Ptr is access constant String;
      T1  : aliased constant String := "4111111111111111";
      T2  : aliased constant String := "4012888888881881";
      T3  : aliased constant String := "4242424242424242";
      T4  : aliased constant String := "4000000000000002";
      T5  : aliased constant String := "5555555555554444";
      T6  : aliased constant String := "5105105105105100";
      T7  : aliased constant String := "2223003122003222";
      T8  : aliased constant String := "378282246310005";
      T9  : aliased constant String := "371449635398431";
      T10 : aliased constant String := "6011111111111117";
      T11 : aliased constant String := "6011000990139424";
      T12 : aliased constant String := "30569309025904";
      T13 : aliased constant String := "38520000023237";
      T14 : aliased constant String := "3530111333300000";
      T15 : aliased constant String := "3566002020360505";
      List : constant array (1 .. 15) of Str_Ptr :=
        (T1'Access, T2'Access, T3'Access, T4'Access, T5'Access, T6'Access,
         T7'Access, T8'Access, T9'Access, T10'Access, T11'Access,
         T12'Access, T13'Access, T14'Access, T15'Access);
   begin
      for P of List loop
         if P.all = Number then
            return True;
         end if;
      end loop;
      return False;
   end Is_Test_Number;

   function Mask (Number : String) return String is
      R : String (1 .. Number'Length) := Number;
   begin
      for I in 7 .. R'Last - 4 loop
         R (I) := '*';
      end loop;
      return R;
   end Mask;

   procedure Scan_Line
     (Line : String; Found : out Match_Array; Count : out Natural)
   is
      I      : Natural := Line'First;
      Buf    : String (1 .. 64);
      N      : Natural;
      Start  : Natural;
      J      : Natural;
      Last_D : Natural;
      Too_Long : Boolean;
   begin
      Count := 0;
      while I <= Line'Last loop
         if Is_Digit (Line (I))
           and then (I = Line'First or else not Is_Digit (Line (I - 1)))
         then
            Start := I;
            N := 0;
            J := I;
            Last_D := I;
            Too_Long := False;
            loop
               --  consume a group of digits
               while J <= Line'Last and then Is_Digit (Line (J)) loop
                  if N < Buf'Last then
                     N := N + 1;
                     Buf (N) := Line (J);
                  else
                     Too_Long := True;
                  end if;
                  Last_D := J;
                  J := J + 1;
               end loop;
               --  a single space or hyphen followed by a digit continues the number
               exit when not (J < Line'Last
                              and then (Line (J) = ' ' or else Line (J) = '-')
                              and then Is_Digit (Line (J + 1)));
               J := J + 1;
            end loop;
            if not Too_Long and then N in 13 .. 19 and then Luhn_Valid (Buf (1 .. N))
              and then Count < Max_Matches
            then
               Count := Count + 1;
               Found (Found'First + Count - 1) :=
                 (Column  => Start - Line'First + 1,
                  Number_Len => N,
                  Masked  => (others => ' '),
                  Kind    => Brand_Of (Buf (1 .. N)),
                  Is_Test => Is_Test_Number (Buf (1 .. N)));
               Found (Found'First + Count - 1).Masked (1 .. N) := Mask (Buf (1 .. N));
            end if;
            I := Last_D + 1;
         else
            I := I + 1;
         end if;
      end loop;
   end Scan_Line;

end Card_Scan;

{ pkgs, ... }:

{
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        qt6Packages.fcitx5-configtool
        qt6Packages.fcitx5-chinese-addons
        fcitx5-mozc # Japanese input method
        fcitx5-gtk # gtk im module
      ];
      settings = {
        inputMethod = {
          GroupOrder."0" = "Default";
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "shuangpin";
          };
          "Groups/0/Items/0" = {
            Name = "keyboard-us";
            Layout = "us";
          };
          "Groups/0/Items/1" = {
            Name = "shuangpin";
            Layout = null;
          };
          "Groups/0/Items/2" = {
            Name = "mozc";
            Layout = null;
          };
        };

        addons = {
          classicui.globalSection = {
            "Vertical Candidate List" = "False";
            PerScreenDPI = "True";
            WheelForPaging = "True";
            TrayOutlineColor = "#000000";
            TrayTextColor = "#ffffff";
            PreferTextIcon = "False";
            ShowLayoutNameInIcon = "True";
            UseInputMethodLangaugeToDisplayText = "True";
            ForceWaylandDPI = 0;
          };

          xim.globalSection = {
            UseOnTheSpot = "True";
          };

          pinyin.globalSection = {
            ShuangpinProfile = "Xiaohe";
            UseShuangpin = "True";
            ShowShuangpinMode = "True";
            PageSize = 7;
            SpellEnabled = "True";
            SymbolsEnabled = "True";
            ChaiziEnabled = "True";
            ExtBEnabled = "True";
            StrokeCandidateEnabled = "True";
            CloudPinyinEnabled = "False";
            PreeditMode = "Composing pinyin";
            PreeditCursorPositionAtBeginning = "True";
            PinyinInPreedit = "True";
            Prediction = "False";
            PredictionSize = 49;
            BackspaceBehaviorOnPrediction = "Backspace when not using on-screen keyboard";
            SwitchInputMethodBehavior = "Commit current preedit";
            SecondCandidate = "";
            ThirdCandidate = "";
            UseKeypadAsSelection = "False";
            BackSpaceToUnselect = "True";
            "Number of sentence" = 2;
            WordCandidateLimit = 15;
            LongWordLengthLimit = 4;
            QuickPhraseKey = "semicolon";
            VAsQuickphrase = "True";
            FirstRun = "False";
          };

          pinyin.sections = {
            ForgetWord."0" = "Control+7";

            PrevPage = {
              "0" = "minus";
              "1" = "Up";
              "2" = "KP_Up";
              "3" = "Page_Up";
            };

            NextPage = {
              "0" = "equal";
              "1" = "Down";
              "2" = "KP_Down";
              "3" = "Next";
            };

            PrevCandidate."0" = "Shift+Tab";
            NextCandidate."0" = "Tab";

            CurrentCandidate = {
              "0" = "space";
              "1" = "KP_Space";
            };

            CommitRawInput = {
              "0" = "Return";
              "1" = "KP_Enter";
              "2" = "Control+Return";
              "3" = "Control+KP_Enter";
              "4" = "Shift+Return";
              "5" = "Shift+KP_Enter";
              "6" = "Control+Shift+Return";
              "7" = "Control+Shift+KP_Enter";
            };

            ChooseCharFromPhrase = {
              "0" = "bracketleft";
              "1" = "bracketright";
            };

            FilterByStroke."0" = "grave";

            QuickPhraseTriggerRegex = {
              "0" = ".(/|@)$";
              "1" = "^(www|bbs|forum|mail|bbs)\\.";
              "2" = "^(http|https|ftp|telnet|mailto):";
            };

            Fuzzy = {
              VE_UE = "True";
              NG_GN = "True";
              Inner = "True";
              InnerShort = "True";
              PartialFinal = "True";
              PartialSp = "False";
              V_U = "False";
              AN_ANG = "False";
              EN_ENG = "False";
              IAN_IANG = "False";
              IN_ING = "False";
              U_OU = "False";
              UAN_UANG = "False";
              C_CH = "False";
              F_H = "False";
              L_N = "False";
              L_R = "False";
              S_SH = "False";
              Z_ZH = "False";
              Correction = "None";
            };
          };
        };
      };
    };
  };
}

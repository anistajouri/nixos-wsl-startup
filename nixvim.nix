{
  # FIXME: you can put anything under the "Options" section of the NixVim docs here
  # https://nix-community.github.io/nixvim/

  # some examples...

  # all your regular vim options here
  options = {
    textwidth = 120;
  };

  config = {
  # add your own personal keymaps preferences
    keymaps = [
      {
        mode = "n";
        action = ":vsplit<CR>";
        key = "|";
      }

      {
        mode = "n";
        action = ":split<CR>";
        key = "-";
      }

      # Explain Code
      {
        mode = "n";
        key = "<leader>ce";  # Space + ce
        action = ":CopilotChatExplain<CR>";
        options = {
          desc = "Copilot Explain Code";
          silent = true;
        };
      }
      # Fix Code
      {
        mode = "n";
        key = "<leader>cf";  # Space + cf
        action = ":CopilotChatFix<CR>";
        options = {
          desc = "Copilot Fix Code";
          silent = true;
        };
      }
      # Optimize Code
      {
        mode = "n";
        key = "<leader>co";  # Space + co
        action = ":CopilotChatOptimize<CR>";
        options = {
          desc = "Copilot Optimize Code";
          silent = true;
        };
      }
      # Generate Tests
      {
        mode = "n";
        key = "<leader>ct";  # Space + ct
        action = ":CopilotChatTests<CR>";
        options = {
          desc = "Copilot Generate Tests";
          silent = true;
        };
      }
      # Add Documentation
      {
        mode = "n";
        key = "<leader>cd";  # Space + cd
        action = ":CopilotChatDocs<CR>";
        options = {
          desc = "Copilot Add Documentation";
          silent = true;
        };
      }
      # Open Chat (bonus)
      {
        mode = "n";
        key = "<leader>cc";  # Space + cc
        action = ":CopilotChat<CR>";
        options = {
          desc = "Open Copilot Chat";
          silent = true;
        };
      }

    ];


    plugins = {
      lsp.servers = {
        # full list of language servers you can enable on the left bar here:
        # https://nix-community.github.io/nixvim/plugins/lsp/servers/ansiblels/index.html

        graphql.enable = true;
      };

      # full list of plugins on the left bar here:
      # https://nix-community.github.io/nixvim/plugins/airline/index.html

      # check all plugins you want to enable
      # like for copilot chat https://nix-community.github.io/nixvim/plugins/copilot-chat/index.html
      markdown-preview.enable = true;
      copilot-chat.enable = true;
      copilot-vim.enable = true;
    };
  };
}
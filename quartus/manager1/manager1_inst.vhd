	component manager1 is
		port (
			source     : out std_logic_vector(2 downto 0);        -- source
			source_clk : in  std_logic                    := 'X'  -- clk
		);
	end component manager1;

	u0 : component manager1
		port map (
			source     => CONNECTED_TO_source,     --    sources.source
			source_clk => CONNECTED_TO_source_clk  -- source_clk.clk
		);


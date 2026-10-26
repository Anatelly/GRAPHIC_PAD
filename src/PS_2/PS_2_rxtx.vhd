library ieee;
use ieee.std_logic_1164.all;

entity PS_2_rxtx is
	port(
		clk : in std_logic;
		reset : in std_logic;
		wr_ps2 : in std_logic;
		ps2d : inout std_logic;
		ps2c : inout std_logic;
		din : in std_logic_vector(7 downto 0);
		tx_done_tick : out std_logic;
		rx_done_tick : out std_logic;
		dout : out std_logic_vector(7 downto 0)
	);
end entity; 

architecture arch of PS_2_rxtx is


signal tx_idle : std_logic;

begin

ps2_rx_unit : entity work.PS_2_rx
	port map(
	clk => clk,
	reset => reset,
	rx_en => tx_idle,
	ps2d => ps2d,
	ps2c => ps2c,
	rx_done_tick => rx_done_tick,
	dout => dout
	);
	
ps2_tx_unit : entity work.PS_2_tx
	port map(
	clk => clk,
	reset => reset,
	wr_ps2 => wr_ps2,
	din => din,
	ps2d => ps2d,
	ps2c => ps2c,
	tx_idle => tx_idle,
	tx_done_tick => tx_done_tick
	);
	
end architecture;
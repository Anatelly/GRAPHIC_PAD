library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PS_2_rx is
	port(
		clk : in std_logic;
		reset : in std_logic;
		ps2d : in std_logic;
		ps2c : in std_logic;
		rx_en : in std_logic;
		rx_done_tick : out std_logic;
		dout : out std_logic_vector (7 downto 0)
	);
end entity;

architecture rtl of PS_2_rx is

type state_type is (idle, rts, start, data, stop);
signal state_reg, state_next : state_type;

signal filter_reg : std_logic_vector(7 downto 0);
signal filter_next : std_logic_vector(7 downto 0);
signal f_ps2c_reg : std_logic;
signal f_ps2c_next : std_logic;
signal n_reg : std_logic_vector(3 downto 0);
signal n_next : std_logic_vector(3 downto 0);
signal b_reg : std_logic_vector(10 downto 0);
signal b_next : std_logic_vector(10 downto 0);
signal fall_edge : std_logic;

begin

	process(clk, reset)
	begin
		if reset = '1' then
			filter_reg <= (others => '0');
			f_ps2c_reg <= '0';
		elsif rising_edge(clk) then
			filter_reg <= filter_next;
			f_ps2c_reg <= f_ps2c_next;
		end if;
	end process;
	
filter_next <= ps2c & filter_reg(7 downto 1);
f_ps2c_next <= '1' when filter_reg = "11111111" else
					'0' when filter_reg = "00000000" else
					f_ps2c_reg;
fall_edge <= f_ps2c_reg and (not f_ps2c_next);

	process(clk, reset)
	begin
		if reset = '1' then
			state_reg <= idle;
			n_reg <= (others => '0');
			b_reg <= (others => '0');
		elsif rising_edge(clk) then
			state_reg <= state_next;
			n_reg <= n_next;
			b_reg <= b_next;
		end if;
	end process;
	
	process(state_reg, n_reg, b_reg, rx_en, fall_edge, ps2d)
	begin
		state_next <= state_reg;
		rx_done_tick <= '0';
      n_next <= n_reg;
      b_next <= b_reg;
		
				case state_reg is
					when idle =>
						if fall_edge = '1' and rx_en = '1' then
							b_next <= ps2d & b_reg(10 downto 1);
							N_next <= "1001";
							state_next <= start;
						end if;
					
					when start =>
						if fall_edge = '1' then
							b_next <= ps2d & b_reg(10 downto 1);
							if n_reg = "0000" then
								state_next <= stop;
							else
								n_next <= std_logic_vector(unsigned(n_reg) - 1);
							end if;
						end if;
						
					when stop =>
						if fall_edge = '1' then
							state_next <= idle;
							rx_done_tick <= '1';
						end if;
						
					when others =>
						state_next <= idle;
				
				end case;
					
	end process;
	
dout <= b_reg(8 downto 1);
	
end architecture;
	
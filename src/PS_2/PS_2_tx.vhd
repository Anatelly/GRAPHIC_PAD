library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PS_2_tx is
	port(
		clk : in std_logic;
		reset : in std_logic;
		wr_ps2 : in std_logic;
		din : in std_logic_vector (7 downto 0);
		ps2d : inout std_logic;
		ps2c : inout std_logic;
		tx_idle : out std_logic;
		tx_done_tick : out std_logic
	);
end entity;

architecture rtl of PS_2_tx is

type state_type is (idle, rts, start, data, stop);
signal state_reg, state_next : state_type;

signal filter_reg : std_logic_vector(7 downto 0);
signal filter_next : std_logic_vector(7 downto 0);
signal f_ps2c_reg : std_logic;
signal f_ps2c_next : std_logic;
signal n_reg : std_logic_vector(3 downto 0);
signal n_next : std_logic_vector(3 downto 0);
signal b_reg : std_logic_vector(8 downto 0);
signal b_next : std_logic_vector(8 downto 0);
signal c_reg : std_logic_vector(12 downto 0);
signal c_next : std_logic_vector(12 downto 0);
signal par : std_logic;
signal fall_edge : std_logic;
signal ps2c_out : std_logic;
signal ps2d_out : std_logic;
signal tri_c : std_logic;
signal tri_d : std_logic;

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
			c_reg <= (others => '0');
			n_reg <= (others => '0');
			b_reg <= (others => '0');
		elsif rising_edge(clk) then
			state_reg <= state_next;
			c_reg <= c_next;
			n_reg <= n_next;
			b_reg <= b_next;
		end if;
	end process;
	
par <= not(din(0) xor din(1) xor din(2) xor din(3) xor din(4) xor din(5) xor din(6) xor din(7));

	process(state_reg, c_reg, n_reg, b_reg, wr_ps2, din, par, fall_edge)
	begin
		state_next <= state_reg;
		c_next <= c_reg;
      n_next <= n_reg;
      b_next <= b_reg;
      tx_done_tick <= '0';
      ps2c_out <= '1';
      ps2d_out <= '1';
      tri_c <= '0';
      tri_d <= '0';
      tx_idle <= '0';
		
				case state_reg is
					when idle =>
						tx_idle <= '1';
						if wr_ps2 = '1' then
							b_next <= par & din(7 downto 0);
							c_next <= "1111111111111";
							state_next <= rts;
						end if;
					
					when rts =>
						ps2c_out <= '0';
						tri_d <= '1';
						if fall_edge = '1' then
							c_next <= std_logic_vector(unsigned(c_reg) - 1);
							if c_reg = "0000" then
								state_next <= start;
							end if;
						end if;
						
					when start =>
						ps2d_out <= '0';
						tri_d <= '1';
							if fall_edge = '1' then
								n_next <= "1000";
								state_next <= data;
							end if;
							
					when data =>
						ps2d_out <= b_reg(0);
						tri_d <= '1';
						if fall_edge = '1' then
							b_next <= '0' & b_reg(8 downto 1);
							if n_reg = "0000" then
								state_next <= start;
							else
								n_next <= std_logic_vector(unsigned(n_reg) - 1);
							end if;
						end if;
						
						
					when stop =>
						if fall_edge = '1' then
							state_next <= idle;
							tx_done_tick <= '1';
						end if;
						
					when others =>
						state_next <= idle;
				
				end case;
					
	end process;
	
ps2c <= ps2c_out when tri_c = '1' else 'Z';
ps2d <= ps2d_out when tri_d = '1' else 'Z';

	
end architecture;
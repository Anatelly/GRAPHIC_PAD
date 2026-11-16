library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mouse is
	port(
		clk : in std_logic;
		reset : in std_logic;
		ps2d : inout std_logic; -- Линия данных мыши
		ps2c : inout std_logic; -- Тактовый импульс мыши
		xm : out std_logic_vector(8 downto 0); -- Положение курсора X
		ym : out std_logic_vector(8 downto 0); -- Положение курсора Y
		btnm : out std_logic_vector(2 downto 0); -- Кнопки: левая, правая, средняя
		data_update : out std_logic
	);
end entity; 

architecture arch of mouse is

--constant MOUSE_RESET : std_logic_vector(7 downto 0) := "11111111";
constant MOUSE_ENABLE : std_logic_vector(7 downto 0) := "11110100";
constant MOUSE_ACK : std_logic_vector(7 downto 0) := "11111010";

type state_type is (init1, init2, init3, pack1, pack2, pack3, done);
signal state_reg : state_type;

signal rx_data : std_logic_vector(7 downto 0);
signal wr_ps2 : std_logic;
signal rx_done_tick : std_logic;
signal tx_done_tick : std_logic;
signal x_reg : std_logic_vector(8 downto 0);
signal y_reg : std_logic_vector(8 downto 0);
signal btn_reg : std_logic_vector(2 downto 0);
signal overflow_x_reg : std_logic;
signal overflow_y_reg : std_logic;
signal data_update_reg : std_logic;
begin

 -----------------------------------------------------------------
    -- Инициализация ps2_rxtx
 -----------------------------------------------------------------

ps2_unit : entity work.PS_2_rxtx
	port map (
		clk => clk,
		reset => reset,
		wr_ps2 => wr_ps2,
		din => MOUSE_ENABLE,
		ps2d => ps2d,
		ps2c => ps2c,
		rx_done_tick => rx_done_tick,
		tx_done_tick => tx_done_tick,
		dout => rx_data
		);


-----------------------------------------------------------------
    -- Регистры состояний и данных FSMD (Синхронный блок)
-----------------------------------------------------------------
	
	mouse_proc : process(clk, reset)
	begin
		if reset = '0' then
				state_reg <= init1;
				x_reg <= (others => '0');
				y_reg <= (others => '0');
				btn_reg <= (others => '0');
				data_update_reg <= '0';
				overflow_x_reg <= '0';
				overflow_y_reg <= '0';
				wr_ps2 <= '0';
		
		elsif rising_edge(clk) then
		
			data_update_reg <= '0';
			wr_ps2 <= '0';
			
			case state_reg is
				when init1 =>
					wr_ps2 <= '1';
					state_reg <= init2;
					
				when init2 => -- Ожидание завершения отправки
					if tx_done_tick = '1' then
						state_reg <= init3;
					end if;

				when init3 => -- Ожидание пакета подтверждения (ACK)
					if rx_done_tick = '1' then
						if rx_data = MOUSE_ACK then
							state_reg <= pack1;
						end if;
					end if;

				when pack1 => -- Ожидание 1-го пакета данных (флаги, знаковые биты, кнопки)
					if rx_done_tick = '1' then
						if rx_data(3) = '1' then
							btn_reg <= rx_data(2 downto 0); -- Кнопки: Средняя, Правая, Левая
							x_reg(8) <= rx_data(4); -- Знаковый бит X
							y_reg(8) <= rx_data(5); -- Знаковый бит Y
							overflow_x_reg <= rx_data(6); -- Переполнение X
							overflow_y_reg <= rx_data(7); -- Переполнение Y
							state_reg <= pack2;
						end if;
					end if;

				when pack2 => -- Ожидание 2-го пакета данных (смещение по X)
					if rx_done_tick = '1' then
						if overflow_x_reg = '1' then
							x_reg(7 downto 0) <= (others => '1');
						else
							x_reg(7 downto 0) <= rx_data;	
						end if;
						state_reg <= pack3;
				end if;

				when pack3 => -- Ожидание 3-го пакета данных (смещение по Y)
					if rx_done_tick = '1' then
						if overflow_y_reg = '1' then
							y_reg(7 downto 0) <= (others => '1');
						else
							y_reg(7 downto 0) <= rx_data;
						end if;
						state_reg <= done;
					end if;
					
				when done =>
					data_update_reg <= '1';
					state_reg <= pack1;
				
					
			end case;
			
		end if;
	-- Назначение выходных сигналов
	xm <= x_reg;
	ym <= y_reg;
	btnm <= btn_reg;
	data_update <= data_update_reg;
	end process mouse_proc;


end architecture;

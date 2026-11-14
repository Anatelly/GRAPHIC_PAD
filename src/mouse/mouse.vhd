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
signal state_reg, state_next : state_type;

signal rx_data : std_logic_vector(7 downto 0);
signal wr_ps2 : std_logic;
signal rx_done_tick : std_logic;
signal tx_done_tick : std_logic;
signal x_reg : std_logic_vector(8 downto 0);
signal y_reg : std_logic_vector(8 downto 0);
signal x_next : std_logic_vector(8 downto 0);
signal y_next : std_logic_vector(8 downto 0);
signal btn_reg : std_logic_vector(2 downto 0);
signal btn_next : std_logic_vector(2 downto 0);
signal overflow_x_next : std_logic;
signal overflow_y_next : std_logic;
signal overflow_x_reg : std_logic;
signal overflow_y_reg : std_logic;

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

	process(clk, reset)
	begin
		if reset = '1' then
			state_reg <= init1;
			x_reg <= (others => '0');
			y_reg <= (others => '0');
			btn_reg <= (others => '0');
			overflow_x_reg <= '0';
			overflow_y_reg <= '0';
		elsif rising_edge(clk) then
			state_reg <= state_next;
			x_reg <= x_next;
			y_reg <= y_next;
			btn_reg <= btn_next;
			overflow_x_reg <= overflow_x_next;
			overflow_y_reg <= overflow_y_next;
		end if;
	end process;

-----------------------------------------------------------------
    -- Регистры состояний и данных FSMD (Синхронный блок)
-----------------------------------------------------------------
	
	process(state_reg, rx_done_tick, tx_done_tick, x_reg, y_reg, btn_reg, rx_data, overflow_x_reg, overflow_y_reg)
	begin
	-- Назначения по умолчанию для предотвращения генерации защелок
		state_next <= state_reg;
      x_next <= x_reg;
      y_next <= y_reg;
      btn_next <= btn_reg;
		overflow_x_reg <= overflow_x_next;
		overflow_y_reg <= overflow_y_next;
		wr_ps2 <= '0';
		data_update <= '0';
		
			case state_reg is
				when init1 =>
					wr_ps2 <= '1';
					state_next <= init2;
					
				when init2 => -- Ожидание завершения отправки
					if tx_done_tick = '1' then
						state_next <= init3;
					end if;

				when init3 => -- Ожидание пакета подтверждения (ACK)
					if rx_done_tick = '1' then
						if rx_data = MOUSE_ACK then
							state_next <= pack1;
						end if;
					end if;

				when pack1 => -- Ожидание 1-го пакета данных (флаги, знаковые биты, кнопки)
					if rx_done_tick = '1' then
						if rx_data(3) = '1' then
							btn_next <= rx_data(2 downto 0); -- Кнопки: Средняя, Правая, Левая
							x_next(8) <= rx_data(4); -- Знаковый бит X
							y_next(8) <= rx_data(5); -- Знаковый бит Y
							overflow_x_next <= rx_data(6); -- Переполнение X
							overflow_y_next <= rx_data(7); -- Переполнение Y
							state_next <= pack2;
						end if;
					end if;

				when pack2 => -- Ожидание 2-го пакета данных (смещение по X)
					if rx_done_tick = '1' then
						if overflow_x_next = '1' then
							x_next(7 downto 0) <= (others => '1');
						else
							x_next(7 downto 0) <= rx_data;	
						end if;
						state_next <= pack3;
				end if;

				when pack3 => -- Ожидание 3-го пакета данных (смещение по Y)
					if rx_done_tick = '1' then
						if overflow_y_next = '1' then
							y_next(7 downto 0) <= (others => '1');
						else
							y_next(7 downto 0) <= rx_data;
						end if;
						state_next <= done;
					end if;
					
				when done =>
					data_update <= '1';
					state_next <= pack1;

					
			end case;
	end process;

-----------------------------------------------------------------
    -- Назначение выходных сигналов
-----------------------------------------------------------------
	
xm <= x_reg;
ym <= y_reg;
btnm <= btn_reg;

end architecture;

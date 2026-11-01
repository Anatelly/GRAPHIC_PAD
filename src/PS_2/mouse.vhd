library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mouse is
	port(
		clk : in std_logic;
		reset : in std_logic;
		ps2d : inout std_logic;
		ps2c : inout std_logic;
		xm : out std_logic_vector(7 downto 0);
		ym : out std_logic_vector(8 downto 0);
		data_update   : out std_logic; -- Строб обновления данных
		--Вывод информации о нажатых клавишах
		left_button   : out std_logic;
		right_button  : out std_logic
	);
end entity; 

architecture arch of mouse is

constant MOUSE_RESET   : std_logic_vector(7 downto 0) := x"FF";
constant MOUSE_ENABLE  : std_logic_vector(7 downto 0) := x"F4";
constant MOUSE_ACK    : std_logic_vector(7 downto 0) := x"FA";

type state_type is (init1, init2, init3, pack1, pack2, pack3, done);
signal state_reg, state_next : state_type;

signal rx_data : std_logic_vector(7 downto 0);
signal wr_ps2 : std_logic;
signal rx_done_tick : std_logic;
signal tx_done_tick : std_logic;
signal btn_reg : std_logic_vector(2 downto 0);
signal btn_next : std_logic_vector(2 downto 0);
signal x_sign : std_logic;
signal y_sign : std_logic;
-- Диапазон координат ограничен экраном монитора
signal x_reg : integer range 0 to 239;
signal x_next : integer range 0 to 239;
signal y_reg : integer range 0 to 319;
signal y_next : integer range 0 to 319;
signal update_tick : std_logic; -- Строб для вывода обновления
-- Сигналы для расчета изменения координат
signal change_x : integer range -256 to 255;
signal change_y : integer range -256 to 255;
signal new_x : integer;
signal new_y : integer;


begin

 -----------------------------------------------------------------
    -- Инициализация приемопередатчика ps2_rxtx
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

change_x <= to_integer(signed(rx_data)) - 256 when x_sign = '1' else to_integer(unsigned(rx_data));
change_y <= to_integer(signed(rx_data)) - 256 when y_sign = '1' else to_integer(unsigned(rx_data));

new_x <= x_reg + change_x;
new_y <= x_reg + change_y;

-----------------------------------------------------------------
    -- Регистры состояний и данных FSMD (Синхронный блок)
-----------------------------------------------------------------

	process(clk, reset)
	begin
		if reset = '0' then
			state_reg <= init1;
			x_reg <= 0;
			y_reg <= 0;
			btn_reg <= (others => '0');
			x_sign <= '0';
			y_sign <= '0';
		elsif rising_edge(clk) then
			state_reg <= state_next;
			x_reg <= x_next;
			y_reg <= y_next;
			btn_reg <= btn_next;
			if state_reg = pack1 and rx_done_tick = '1' then
				y_sign <= rx_data(5);
				x_sign <= rx_data(4);
			end if;
		end if;
	end process;

---------------------------------------
    -- Регистры состояний и данных FSMD
---------------------------------------
	
	process(all)
	begin
	-- Назначения по умолчанию для предотвращения генерации защелок
		state_next <= state_reg;
		wr_ps2 <= '0';
      update_tick <= '0';
      x_next <= x_reg;
      y_next <= y_reg;
      btn_next <= btn_reg;
		
			case state_reg is
				when init1 =>
					wr_ps2 <= '1';
					state_next <= init2;
					
				when init2 => -- Ожидание завершения отправки
					if rx_done_tick = '1' then
						state_next <= init3;
					end if;

				when init3 => -- Ожидание пакета подтверждения (ACK)
					if rx_done_tick = '1' then
						state_next <= pack1;
					end if;


				when pack1 => -- Ожидание 1-го пакета данных (флаги, знаковые биты, кнопки)
					if rx_done_tick = '1' then
						state_next <= pack2;
--						y_next(8) <= rx_data(5); -- Знаковый бит Y
--						x_next(8) <= rx_data(4); -- Знаковый бит X
						btn_next <= rx_data(2 downto 0); -- Кнопки: Средняя, Правая, Левая
					end if;

				-- Ожидание 2-го пакета данных (смещение по X)
				when pack2 =>
					if rx_done_tick = '1' then
						state_next <= pack3;
						-- Накапливаем координаты только если зажата ЛЕВАЯ или ПРАВАЯ кнопка
						if btn_reg(0) = '1' or btn_reg(1) = '1' then
							-- Ограничиваем края экрана LT24 по оси X (0..239)
							if new_x < 0 then
								x_next <= 0;
							elsif new_x > 239 then
								x_next <= 239;
							else
								x_next <= new_x;
							end if;
						end if;
					end if;

				when pack3 => -- Ожидание 3-го пакета данных (смещение по Y)
					if rx_done_tick = '1' then
					state_next <= done;
					-- Накапливаем координаты только если зажата ЛЕВАЯ или ПРАВАЯ кнопка
					if btn_reg(0) = '1' or btn_reg(1) = '1' then
						-- Ограничиваем края экрана LT24 по оси Y (0..319)
						if new_y < 0 then
							y_next <= 0;
						elsif new_y > 319 then
							y_next <= 319;
						else
							y_next <= new_y;
						end if;
					end if;
				end if;

				when done =>
					if btn_reg(0) = '1' or btn_reg(1) = '1' then
						update_tick <= '1'; -- Строб генерируется только при нажатой кнопке
					end if;
					state_next <= pack1;

				when others =>
					state_next <= init1;
					
			end case;
	end process;

-----------------------------------------------------------------
    -- Назначение выходных сигналов
-----------------------------------------------------------------
	
xm <= std_logic_vector(to_unsigned(x_reg, 8));
ym <= std_logic_vector(to_unsigned(y_reg, 9));
data_update <= update_tick;

left_button  <= btn_reg(0);
right_button <= btn_reg(1);

end architecture;
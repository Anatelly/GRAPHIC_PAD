library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera;
use altera.altera_primitives_components.all;

-- Модуль передатчика PS/2 (Хост -> Устройство).
-- Используется для отправки команд управления (например, включения мыши x"F4").

entity PS_2_tx is
	port(
		clk : in std_logic;
		reset : in std_logic;
		wr_ps2 : in std_logic; -- Импульс записи (команда на начало передачи байта)
		din : in std_logic_vector(7 downto 0); -- Восемь бит отправляемых данных
		ps2d : inout std_logic; -- Двунаправленная линия данных PS/2
		ps2c : inout std_logic; -- Двунаправленная линия тактовых импульсов PS/2
		tx_idle : out std_logic; -- Флаг готовности: '1' означает, что передатчик свободен
		tx_done_tick : out std_logic -- Генерация строба (импульса) по окончании успешной передачи
	);
end entity;

architecture rtl of PS_2_tx is

-- idle  : ожидание команды на отправку
-- rts   : запрос на отправку (Request to Send) — хост принудительно прижимает линию тактов к нулю
-- start : передача стартового бита (прижатие линии данных к нулю)
-- data  : последовательная передача 8 бит данных и 1 бита четности
-- stop  : прием стоп-бита от устройства и ожидание импульса подтверждения (ACK)
type state_type is (idle, rts, start, data, stop);
signal state_reg, state_next : state_type;

signal filter_reg : std_logic_vector(7 downto 0);
signal filter_next : std_logic_vector(7 downto 0);
signal f_ps2c_reg : std_logic;
signal f_ps2c_next : std_logic;
signal n_reg : unsigned(3 downto 0); -- Счетчик переданных бит (всего 8 бит данных + 1 бит четности)
signal b_reg : std_logic_vector(8 downto 0); -- Сдвиговый регистр для передачи бит в линию
signal c_reg : unsigned(12 downto 0); -- Счетчик задержки (таймер) для удержания линии тактов в состоянии RTS
signal par : std_logic;
signal fall_edge : std_logic; -- Импульс, фиксирующий спадающий фронт линии тактов мыши
signal ps2c_out : std_logic;
signal ps2d_out : std_logic;
signal tri_c : std_logic;
signal tri_d : std_logic;

begin

filter_next <= ps2c & filter_reg(7 downto 1);
f_ps2c_next <= '1' when filter_reg = "11111111" else
					'0' when filter_reg = "00000000" else
					f_ps2c_reg;
					
fall_edge <= f_ps2c_reg and (not f_ps2c_next);

	-- Генерация бита нечетного паритета (Odd Parity). 
	-- Согласно стандарту PS/2, общее число единиц в байте данных и бите паритета должно быть нечетным.
par <= not(din(7) xor din(6) xor din(5) xor din(4) xor din(3) xor din(2) xor din(1) xor din(0));


------------------------------------------------------------------
	-- КОНЕЧНЫЙ АВТОМАТ УПРАВЛЕНИЯ ПЕРЕДАЧЕЙ (FSM)
------------------------------------------------------------------
	sm_tx : process(clk, reset)
		begin
			if reset = '0' then
				state_reg <= idle;
				filter_reg <= (others => '0');
				f_ps2c_reg <= '0';
				c_reg <= (others => '0');
				n_reg <= (others => '0');
				b_reg <= (others => '0');
				tx_done_tick <= '0';
				tx_idle <= '0';
				ps2c_out <= '1';
				ps2d_out <= '1';
				tri_c <= '0';
				tri_d <= '0';
			elsif rising_edge(clk) then
				-- Фильтр PS/2 Clock
				filter_reg <= ps2c & filter_reg(7 downto 1);
				f_ps2c_reg <= f_ps2c_next;
				-- Значения по умолчанию
				tx_done_tick <= '0';
				tx_idle <= '0';
				ps2c_out <= '1';
				ps2d_out <= '1';
				tri_c <= '0';
				tri_d <= '0';

				case state_reg is

					when idle =>
						tx_idle <= '1';

						if wr_ps2 = '1' then
							b_reg <= par & din;
							c_reg <= (others => '1');
							state_reg <= rts;
						end if;

                when rts => -- request to send (запрос на отправку)
                    ps2c_out <= '0';
                    tri_c <= '1';
                    if c_reg = 0 then
                        state_reg <= start;
                    else
                        c_reg <= c_reg - 1;
                    end if;

                when start => --  assert start bit (установить стартовый бит)
                    ps2d_out <= '0';
                    tri_d <= '1';
                    if fall_edge = '1' then
                        n_reg <= "1000";
                        state_reg <= data;
                    end if;

                when data => -- 8 данных + 1 бит четноти
                    ps2d_out <= b_reg(0);
                    tri_d <= '1';
                    if fall_edge = '1' then
                        b_reg <= '0' & b_reg(8 downto 1);
                        if n_reg = 0 then
                            state_reg <= stop;
                        else
                            n_reg <= n_reg - 1;
                        end if;
                    end if;

                when stop => -- установк высокого уровнядля ps2d
                    if fall_edge = '1' then
                        state_reg <= idle;
                        tx_done_tick <= '1';
                    end if;

            end case;

        end if;
    end process sm_tx;
	
	
i_alt_iobuf_ps2d : alt_iobuf
port map(
	i => ps2d_out,
	oe => tri_d,
	io => ps2d,
	o => open
	);

i_alt_iobuf_ps2c : alt_iobuf
port map(
	i => ps2c_out,
	oe => tri_c,
	io => ps2c,
	o => open
	);
	
--ps2c <= ps2c_out when tri_c = '1' else 'Z';
--ps2d <= ps2d_out when tri_d = '1' else 'Z';

end architecture;

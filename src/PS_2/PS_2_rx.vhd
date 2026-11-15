library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Модуль приемника PS/2 (Устройство -> Хост).
-- Используется для последовательного приема кадров данных от мыши или клавиатуры.

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

-- idle : ожидание стартового бита (прижатия линии данных к нулю)
-- dps  : последовательный прием бит (Data, Parity, Stop)
-- load : завершение приема и выдача готового байта в систему

type state_type is (idle, dps, load);
signal state_reg : state_type;

signal filter_reg : std_logic_vector(7 downto 0);
signal filter_next : std_logic_vector(7 downto 0);
signal f_ps2c_reg : std_logic;
signal f_ps2c_next : std_logic;
signal n_reg : unsigned(3 downto 0);
signal b_reg : std_logic_vector(10 downto 0);
signal fall_edge : std_logic;

begin
	
filter_next <= ps2c & filter_reg(7 downto 1);
f_ps2c_next <= '1' when filter_reg = "11111111" else
					'0' when filter_reg = "00000000" else
					f_ps2c_reg;
fall_edge <= f_ps2c_reg and (not f_ps2c_next);

------------------------------------------------------------------
	-- КОНЕЧНЫЙ АВТОМАТ ПРИЕМА КАДРА PS/2 (FSM)
------------------------------------------------------------------
	
	process(clk, reset)
    begin
        if reset = '1' then
            state_reg <= idle;
            filter_reg <= (others => '0');
            f_ps2c_reg <= '0';
            n_reg <= (others => '0');
            b_reg <= (others => '0');
            rx_done_tick <= '0';
        elsif rising_edge(clk) then
            -- Фильтр тактовой линии PS/2
            filter_reg <= ps2c & filter_reg(7 downto 1);
            f_ps2c_reg <= f_ps2c_next;
            -- Значение по умолчанию: импульс длится один такт
            rx_done_tick <= '0';
				
            case state_reg is
				
                when idle =>
                    if fall_edge = '1' and rx_en = '1' then
                        b_reg <= ps2d & b_reg(10 downto 1);
                        n_reg <= "1001";
                        state_reg <= dps;
                    end if;

                when dps => -- 8 битов данных, 1 бит четности, 1 стоповый бит
                    if fall_edge = '1' then
                        b_reg <= ps2d & b_reg(10 downto 1);

                        if n_reg = 0 then
                            state_reg <= load;
                        else
                            n_reg <= n_reg - 1;
                        end if;
                    end if;

                when load =>
                    state_reg <= idle;
                    rx_done_tick <= '1';

                when others =>
                    state_reg <= idle;

            end case;
        end if;
    end process;
	
dout <= b_reg(8 downto 1); -- 8 битов данных
	
end architecture;
	
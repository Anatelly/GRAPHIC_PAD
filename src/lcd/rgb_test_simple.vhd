
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rgb_test_simple is
    generic (
        START_DELAY_CYCLES : positive := 50_000_000
    );
    port (
        clk   : in std_logic;
        rst_n : in std_logic;

        -- Сигналы управления дисплеем
        frame_upd_start  : out std_logic;
        single_upd_start : out std_logic;
        x_coordinate     : out std_logic_vector(8 downto 0);
        y_coordinate     : out std_logic_vector(8 downto 0);

        -- Данные пикселей
        data_buf_valid : out std_logic;
        data_buff      : out std_logic_vector(15 downto 0);

        -- Сигналы обратной связи от display
        frame_update  : in std_logic;
        sleep_off     : in std_logic;
        data_bvld_ack : in std_logic
    );
end entity rgb_test_simple;


architecture rtl of rgb_test_simple is

    signal delay_cnt : integer range 0 to START_DELAY_CYCLES := 0;
    signal start_done : std_logic := '0';

begin

    -- Обновляем полный кадр один раз после задержки.
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            delay_cnt       <= 0;
            start_done      <= '0';
            frame_upd_start <= '0';

        elsif rising_edge(clk) then
            frame_upd_start <= '0';

            if start_done = '0' then
                if delay_cnt < START_DELAY_CYCLES then
                    delay_cnt <= delay_cnt + 1;
                else
                    frame_upd_start <= '1';
                    start_done      <= '1';
                end if;
            end if;
        end if;
    end process;

    -- Полный кадр, поэтому одиночное обновление не используется.
    single_upd_start <= '0';

    -- Координаты для одиночного обновления.
    x_coordinate <= (others => '0');
    y_coordinate <= (others => '0');

    -- Чёрный пиксель RGB565.
    data_buff <= x"F800";

    -- Данные доступны постоянно.
    data_buf_valid <= '1';

end architecture rtl;

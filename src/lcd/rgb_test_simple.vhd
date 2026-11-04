library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rgb_test_simple is
    generic (
        TEST_MODE  : integer := 1 --выбор теста
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
        initial_done  : in std_logic;
        frame_update  : in std_logic;
        sleep_off     : in std_logic;
        data_bvld_ack : in std_logic
    );
end entity rgb_test_simple;


architecture rtl of rgb_test_simple is

    signal start_done : std_logic := '1';

    type test_state_t is (
        TEST_START,
        TEST_SEND,
        TEST_WAIT,
        TEST_NEXT,
        TEST_DONE
    );

    signal test_state : test_state_t := TEST_START;

    signal x_cnt    : integer range 0 to 239 := 0;
    signal row_cnt  : integer range 0 to 9   := 0;
    signal band_cnt : integer range 0 to 2   := 0;

begin
    -- Обновляем полный кадр один раз после задержки.
    process(clk, rst_n)
    begin
        case TEST_MODE is
        when 1 =>
            --Закраска всего экрана одним цветом
            -- Полный кадр, поэтому одиночное обновление не используется.
            single_upd_start <= '0';
            -- Координаты для одиночного обновления.
            x_coordinate <= (others => '0');
            y_coordinate <= (others => '0');

            if rst_n = '0' then
                start_done       <= '1';
                frame_upd_start  <= '0';

            elsif rising_edge(clk) then
                frame_upd_start <= '0';
                -- Синий(красный) пиксель RGB565.
                data_buff <= x"F800";
                -- Данные доступны постоянно.
                data_buf_valid <= '1';

                --если инициализация прошла - начинаем
                if initial_done = '1' then
                    if start_done = '1' or frame_update = '1' then
                        frame_upd_start <= '1';
                    end if;
                    start_done <= '0';
                end if;
            end if;
        when 2 =>
            --Изменение цвета кокретных пикселей

            frame_upd_start <= '0';

            if rst_n = '0' then
                single_upd_start <= '0';
                data_buf_valid   <= '0';

                x_coordinate <= (others => '0');
                y_coordinate <= (others => '0');
                data_buff    <= (others => '0');

                x_cnt    <= 0;
                row_cnt  <= 0;
                band_cnt <= 0;

                test_state <= TEST_START;

            elsif rising_edge(clk) then
                -- Значения по умолчанию
                single_upd_start <= '0';

                if initial_done = '1' then
                    case test_state is

                        -- Подготовка координат пикселя
                        when TEST_START =>

                            x_coordinate <= std_logic_vector(to_unsigned(x_cnt, 9));

                            case band_cnt is
                                when 0 =>
                                    y_coordinate <= std_logic_vector(to_unsigned(50 + row_cnt, 9));

                                when 1 =>
                                    y_coordinate <= std_logic_vector(to_unsigned(100 + row_cnt, 9));

                                when 2 =>
                                    y_coordinate <= std_logic_vector(to_unsigned(150 + row_cnt, 9));

                                when others =>
                                    y_coordinate <= (others => '0');
                            end case;

                            single_upd_start <= '1';

                            test_state <= TEST_SEND;

                        -- Передача цвета пикселя
                        when TEST_SEND =>

                            case band_cnt is
                                when 0 =>
                                    data_buff <= x"F800"; -- Красный -> синий

                                when 1 =>
                                    data_buff <= x"07E0"; -- Зеленый -> Зеленый

                                when 2 =>
                                    data_buff <= x"001F"; -- Синий -> Синий

                                when others =>
                                    data_buff <= x"FFFF";
                            end case;

                            data_buf_valid <= '1';

                            if data_bvld_ack = '1' then
                                data_buf_valid <= '0';
                                test_state <= TEST_WAIT;
                            end if;

                        -- Ожидание завершения обновления пикселя
                        when TEST_WAIT =>

                            if frame_update = '1' then
                                test_state <= TEST_NEXT;
                            end if;

                        -- Переход к следующему пикселю
                        when TEST_NEXT =>

                            if x_cnt < 239 then

                                -- Следующий пиксель строки
                                x_cnt <= x_cnt + 1;
                                test_state <= TEST_START;

                            else

                                -- Конец строки
                                x_cnt <= 0;

                                if row_cnt < 9 then

                                    -- Следующая строка полосы
                                    row_cnt <= row_cnt + 1;
                                    test_state <= TEST_START;

                                else

                                    -- Полоса завершена
                                    row_cnt <= 0;

                                    if band_cnt < 2 then

                                        -- Следующая цветная полоса
                                        band_cnt <= band_cnt + 1;
                                        test_state <= TEST_START;

                                    else

                                        -- Все три полосы нарисованы
                                        test_state <= TEST_DONE;

                                    end if;

                                end if;

                            end if;

                        -- Завершение теста
                        when TEST_DONE =>

                            data_buf_valid   <= '0';
                            single_upd_start <= '0';

                        when others =>

                            test_state <= TEST_START;

                    end case;
                end if;
            end if;
        when others =>
            null;
        end case;
    end process;
end architecture rtl;

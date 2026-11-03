library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity display_cmd2lcd_tb is
    generic (
        TEST_MODE  : integer := 1; --выбор теста
        TEST_TIMER : integer := 0  --использовать таймер 33мс или ускоренную имитацию
    );
end entity display_cmd2lcd_tb;

architecture tb of display_cmd2lcd_tb is

    -- Параметры тестирования
    constant CLOCK_FREQ : natural := 50e6;
    constant CLK_PERIOD : time := 1 sec / CLOCK_FREQ;

    -- Тактирование и сброс
    signal clk_tb : std_logic := '0';
    signal rst_n_tb : std_logic := '0';

    -- Управление дисплеем
    signal trigger_33ms_tb     : std_logic := '0';
    signal frame_upd_start_tb  : std_logic := '0';
    signal single_upd_start_tb : std_logic := '0';

    signal initial_done_tb  : std_logic;
    signal frame_update_tb  : std_logic;
    signal sleep_off_tb     : std_logic;
    signal data_bvld_ack_tb : std_logic;

    -- Интерфейс пиксельного буфера
    signal x_coordinate_tb : std_logic_vector(8 downto 0)
                            := (others => '0');
    signal y_coordinate_tb : std_logic_vector(8 downto 0)
                            := (others => '0');

    signal data_buf_valid_tb : std_logic := '0';
    signal data_buff_tb      : std_logic_vector(15 downto 0)
                              := x"0000";

    -- Интерфейс display -> cmd2lcd
    signal cmd_valid_tb : std_logic;
    signal cmd_tb       : std_logic_vector(7 downto 0);
    signal cmd_cycle_tb : std_logic_vector(15 downto 0);

    signal data_wr_valid_tb : std_logic;
    signal data_wr_tb       : std_logic_vector(15 downto 0);

    -- Обратные сигналы cmd2lcd -> display
    signal ack_wr_tb         : std_logic;
    signal cmd_finish_tb     : std_logic;
    signal wrphase_finish_tb : std_logic;

    -- Интерфейс LCD
    signal csn_tb      : std_logic;
    signal data_cmdn_tb : std_logic;
    signal wrn_tb      : std_logic;
    signal rdn_tb      : std_logic;

    signal data_lcd_tb : std_logic_vector(15 downto 0);

begin

    ----------------------------------------------------------------
    -- Генератор тактового сигнала
    ----------------------------------------------------------------
    clk_tb <= not clk_tb after CLK_PERIOD / 2;

    ----------------------------------------------------------------
    -- Модуль управления дисплеем
    ----------------------------------------------------------------
    dut_display : entity work.display
        port map (
            clk              => clk_tb,
            rst_n            => rst_n_tb,
            trigger_33ms     => trigger_33ms_tb,
            initial_done     => initial_done_tb,

            frame_update     => frame_update_tb,
            sleep_off        => sleep_off_tb,
            data_bvld_ack    => data_bvld_ack_tb,

            frame_upd_start  => frame_upd_start_tb,
            single_upd_start => single_upd_start_tb,

            x_coordinate     => x_coordinate_tb,
            y_coordinate     => y_coordinate_tb,

            data_buf_valid   => data_buf_valid_tb,
            data_buff        => data_buff_tb,

            cmd_valid        => cmd_valid_tb,
            cmd              => cmd_tb,
            cmd_cycle        => cmd_cycle_tb,

            data_wr_valid    => data_wr_valid_tb,
            data_wr          => data_wr_tb,

            ack_wr           => ack_wr_tb,
            cmd_finish       => cmd_finish_tb,
            wrphase_finish   => wrphase_finish_tb
        );

    ----------------------------------------------------------------
    -- Модуль формирования сигналов записи в LCD
    ----------------------------------------------------------------
    dut_cmd2lcd : entity work.cmd2lcd
        generic map (
            W_HIGH_END => 2,
            W_LOW_END  => 2
        )
        port map (
            clk           => clk_tb,
            rst_n         => rst_n_tb,

            cmd_valid     => cmd_valid_tb,
            cmd           => cmd_tb,
            cmd_cycle     => cmd_cycle_tb,

            data_wr_valid => data_wr_valid_tb,
            data_wr       => data_wr_tb,

            ack_wr        => ack_wr_tb,
            cmd_finish    => cmd_finish_tb,
            wrphase_finish => wrphase_finish_tb,

            csn           => csn_tb,
            data_cmdn     => data_cmdn_tb,
            wrn           => wrn_tb,
            rdn           => rdn_tb,

            data_lcd      => data_lcd_tb
        );

    ----------------------------------------------------------------
    -- Ускоренный генератор trigger_33ms для симуляции.
    -- Вместо реального интервала 33 мс импульсы идут часто,
    -- чтобы ускорить инициализацию дисплея.
    ----------------------------------------------------------------
    timer_gen_sim : if TEST_TIMER = 0 generate
        trigger_gen : process
        begin
            trigger_33ms_tb <= '0';

            wait until rst_n_tb = '1';

            loop
                wait for CLK_PERIOD;
                trigger_33ms_tb <= '1';

                wait for CLK_PERIOD;
                trigger_33ms_tb <= '0';
            end loop;
        end process;
    end generate;

    ----------------------------------------------------------------
    -- Модуль управления таймером
    ----------------------------------------------------------------
    timer_gen_real : if TEST_TIMER = 1 generate
        dut_timer : entity work.timer
            port map (
                clk              => clk_tb,
                rst_n            => rst_n_tb,
                trigger_33ms     => trigger_33ms_tb
            );
    end generate;


    ----------------------------------------------------------------
    -- Основной сценарий тестирования
    ----------------------------------------------------------------
    SIM_PROC : process
    begin
        -- Сброс модулей
        rst_n_tb <= '0';

        wait for CLK_PERIOD;
        wait until falling_edge(clk_tb);
        rst_n_tb <= '1';
        report "TB: reset released" severity note;

        -- Ожидаем завершения инициализации дисплея
        wait until initial_done_tb = '1';
        report "TB: display initialized" severity note;

        case TEST_MODE is
            when 1 =>
                --На вход подается только старт обновления экрана без данных.
                --На выходе должны получить тестовые цветные полосы в нижней части экрана 
                --(этот тест заложен в display)

                -- Запускаем обновление полного кадра
                wait until rising_edge(clk_tb);
                frame_upd_start_tb <= '1';
                wait until rising_edge(clk_tb);
                frame_upd_start_tb <= '0';
                report "TB1: full-frame update started 1" severity note;

                data_buf_valid_tb <= '1';

                -- Ждём завершения обновления полного кадра
                wait until frame_update_tb = '1' for 50 ms;

                if frame_update_tb /= '1' then
                    assert false
                        report "TB1 ERROR: frame update timeout"
                        severity failure;
                else
                    report "TB1: full-frame update completed 1"
                        severity note;
                end if;

                -- Запускаем обновление полного кадра
                wait until rising_edge(clk_tb);
                frame_upd_start_tb <= '1';

                wait until rising_edge(clk_tb);
                frame_upd_start_tb <= '0';

                report "TB1: full-frame update started 2" severity note;

                -- Ждём завершения обновления полного кадра
                wait until frame_update_tb = '1' for 50 ms;

                if frame_update_tb /= '1' then
                    assert false
                        report "TB1 ERROR: frame update timeout"
                        severity failure;
                else
                    report "TB1: full-frame update completed 2"
                        severity note;
                end if;
            when 2 =>
                --На вход подается старт обновления экрана и все пиксели красного цвета.
                --На выходе должны получить экран красного цвета

                -- Установка координат начала обновления
                x_coordinate_tb <= (others => '0');
                y_coordinate_tb <= (others => '0');

                -- Запускаем обновление полного кадра
                wait until falling_edge(clk_tb);
                frame_upd_start_tb <= '1';
                wait until falling_edge(clk_tb);
                frame_upd_start_tb <= '0';
                -- wait for CLK_PERIOD*10;
                report "TB2: full-frame update started" severity note;

                -- Передача красных пикселей RGB565: x"F800"
                -- Передача первого слова
                data_buff_tb      <= x"0001";
                data_buf_valid_tb <= '1';

                loop
                    wait until rising_edge(clk_tb);

                    if data_bvld_ack_tb = '1' then
                        -- data_buff_tb <= x"F800"; --будем передавать тестовые данные с увеличаением на 1
                        --будем передавать тестовые данные с увеличаением на 1
                        data_buff_tb <= std_logic_vector(unsigned(data_buff_tb) + 1);
                        data_buf_valid_tb <= '1';
                    end if;

                    exit when frame_update_tb = '1';
                end loop;

                report "TB2: full-frame update completed"
                    severity note;

            when 3 =>
                --Тест обновления 5ти рандомных пикселей через single_upd_start
                --На выходе должны получить экран с измененными 5ю пикселями
                frame_upd_start_tb <= '0'; --не используем тут

                -- Пиксель 1: красный
                x_coordinate_tb <= std_logic_vector(to_unsigned(50, 9));
                y_coordinate_tb <= std_logic_vector(to_unsigned(50, 9));

                single_upd_start_tb <= '1';
                wait until rising_edge(clk_tb);
                single_upd_start_tb <= '0';

                data_buff_tb      <= x"F800";
                data_buf_valid_tb <= '1';

                wait until rising_edge(clk_tb) and data_bvld_ack_tb = '1';
                data_buf_valid_tb <= '0';
                wait until frame_update_tb = '1'; --ждем обновления кадра
                report "TB3: pixel 1 done" severity note;

                -- Пиксель 2: зеленый
                x_coordinate_tb <= std_logic_vector(to_unsigned(100, 9));
                y_coordinate_tb <= std_logic_vector(to_unsigned(70, 9));

                single_upd_start_tb <= '1';
                wait until rising_edge(clk_tb);
                single_upd_start_tb <= '0';

                data_buff_tb      <= x"07E0";
                data_buf_valid_tb <= '1';

                wait until rising_edge(clk_tb) and data_bvld_ack_tb = '1';
                data_buf_valid_tb <= '0';
                wait until frame_update_tb = '1'; --ждем обновления кадра
                report "TB3: pixel 2 done" severity note;

                -- Пиксель 3: синий
                x_coordinate_tb <= std_logic_vector(to_unsigned(150, 9));
                y_coordinate_tb <= std_logic_vector(to_unsigned(120, 9));

                single_upd_start_tb <= '1';
                wait until rising_edge(clk_tb);
                single_upd_start_tb <= '0';

                data_buff_tb      <= x"001F";
                data_buf_valid_tb <= '1';

                wait until rising_edge(clk_tb) and data_bvld_ack_tb = '1';
                data_buf_valid_tb <= '0';
                wait until frame_update_tb = '1'; --ждем обновления кадра
                report "TB3: pixel 3 done" severity note;

                -- Пиксель 4: черный
                x_coordinate_tb <= std_logic_vector(to_unsigned(200, 9));
                y_coordinate_tb <= std_logic_vector(to_unsigned(200, 9));

                single_upd_start_tb <= '1';
                wait until rising_edge(clk_tb);
                single_upd_start_tb <= '0';

                data_buff_tb      <= x"0000";
                data_buf_valid_tb <= '1';

                wait until rising_edge(clk_tb) and data_bvld_ack_tb = '1';
                data_buf_valid_tb <= '0';
                wait until frame_update_tb = '1'; --ждем обновления кадра
                report "TB3: pixel 4 done" severity note;

                -- Пиксель 5: желтый
                x_coordinate_tb <= std_logic_vector(to_unsigned(239, 9));
                y_coordinate_tb <= std_logic_vector(to_unsigned(319, 9));

                single_upd_start_tb <= '1';
                wait until rising_edge(clk_tb);
                single_upd_start_tb <= '0';

                data_buff_tb      <= x"FFE0";
                data_buf_valid_tb <= '1';

                wait until rising_edge(clk_tb) and data_bvld_ack_tb = '1';
                data_buf_valid_tb <= '0';
                wait until frame_update_tb = '1'; --ждем обновления кадра
                report "TB3: pixel 5 done" severity note;

            when others => 
                null;
        end case;

        wait;
    end process;

end architecture tb;

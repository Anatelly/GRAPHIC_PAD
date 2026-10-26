
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lcd_top is
    port (
        -- Системные сигналы
        clk          : in  std_logic;
        rst_n        : in  std_logic;
        frame_update : out std_logic;

        -- Интерфейс LCD
        csn      : out std_logic;
        data_cmdn : out std_logic;
        wrn      : out std_logic;
        rdn      : out std_logic;
        data_lcd : inout std_logic_vector(15 downto 0)
    );
end entity lcd_top;

architecture rtl of lcd_top is

    ----------------------------------------------------------------
    -- Системный сигнал и связка display и rgb_test
    ----------------------------------------------------------------
    signal frame_update_int : std_logic;

    ----------------------------------------------------------------
    -- Сигналы между cmd2lcd и display
    ----------------------------------------------------------------
    signal lcd_write_ack     : std_logic;
    signal lcd_cmd_finish    : std_logic;
    signal lcd_wrphase_finish : std_logic;

    ----------------------------------------------------------------
    -- Сигналы между rgb_test и display
    ----------------------------------------------------------------
    signal frame_upd_start  : std_logic;
    signal single_upd_start : std_logic;
    signal x_coordinate     : std_logic_vector(8 downto 0);
    signal y_coordinate     : std_logic_vector(8 downto 0);
    signal buf_data_valid   : std_logic;
    signal buf_data         : std_logic_vector(15 downto 0);

    ----------------------------------------------------------------
    -- Сигналы управления display
    ----------------------------------------------------------------
    signal sleep_off      : std_logic;
    signal buf_data_ack   : std_logic;
    signal lcd_cmd_valid  : std_logic;
    signal lcd_cmd        : std_logic_vector(7 downto 0);
    signal lcd_rcmd_enb   : std_logic;
    signal lcd_cmd_cycle  : std_logic_vector(15 downto 0);
    signal lcd_wdata_valid : std_logic;
    signal lcd_wdata      : std_logic_vector(15 downto 0);
    signal lcd_read_ack   : std_logic;

    ----------------------------------------------------------------
    -- Сигнал таймера
    ----------------------------------------------------------------
    signal trigger_33ms : std_logic;

    ----------------------------------------------------------------
    -- Объявления компонентов
    ----------------------------------------------------------------
    component cmd2lcd is
        port (
            clk             : in  std_logic;
            rst_n           : in  std_logic;

            ack_wr          : out std_logic;
            cmd_finish      : out std_logic;
            wrphase_finish  : out std_logic;

            cmd_valid       : in  std_logic;
            cmd             : in  std_logic_vector(7 downto 0);
            cmd_cycle       : in  std_logic_vector(15 downto 0);
            data_wr_valid   : in  std_logic;
            data_wr         : in  std_logic_vector(15 downto 0);

            csn             : out std_logic;
            data_cmdn       : out std_logic;
            wrn             : out std_logic;
            rdn             : out std_logic;
            data_lcd        : inout std_logic_vector(15 downto 0)
        );
    end component;

    component rgb_test is
        port (
            clk              : in  std_logic;
            rst_n            : in  std_logic;
            trigger_33ms     : in  std_logic;

            frame_upd_start  : out std_logic;
            -- single_upd_start : out std_logic;
            -- x_coordinate     : out std_logic_vector(8 downto 0);
            -- y_coordinate     : out std_logic_vector(8 downto 0);
            write_enb        : out std_logic;
            data_buff        : out std_logic_vector(15 downto 0);

            frame_end        : in  std_logic;
            sleep_off        : in  std_logic;
            write_enb_ack    : in  std_logic
        );
    end component;

    component display is
        port (
            frame_update     : out std_logic;

            clk              : in  std_logic;
            rst_n            : in  std_logic;
            trigger_33ms     : in  std_logic;

            sleep_off        : out std_logic;
            data_bvld_ack    : out std_logic;

            frame_upd_start  : in  std_logic;
            single_upd_start : in  std_logic;
            x_coordinate     : in  std_logic_vector(8 downto 0);
            y_coordinate     : in  std_logic_vector(8 downto 0);
            data_buf_valid   : in  std_logic;
            data_buff        : in  std_logic_vector(15 downto 0);

            cmd_valid        : out std_logic;
            cmd              : out std_logic_vector(7 downto 0);
            cmd_cycle        : out std_logic_vector(15 downto 0);
            data_wr_valid    : out std_logic;
            data_wr          : out std_logic_vector(15 downto 0);

            ack_wr            : in  std_logic;
            cmd_finish        : in  std_logic;
            wrphase_finish    : in  std_logic
        );
    end component;

    component timer is
        port (
            trigger_33ms : out std_logic;
            clk          : in  std_logic;
            rst_n        : in  std_logic
        );
    end component;

begin
    --связка системного выхода и сигнала
    frame_update <= frame_update_int;
    ----------------------------------------------------------------
    -- Управление физическим интерфейсом LCD
    ----------------------------------------------------------------
    cmd2lcd_u : cmd2lcd
        port map (
            clk              => clk,
            rst_n            => rst_n,

            ack_wr           => lcd_write_ack,
            cmd_finish       => lcd_cmd_finish,
            wrphase_finish   => lcd_wrphase_finish,

            cmd_valid        => lcd_cmd_valid,
            cmd              => lcd_cmd,
            cmd_cycle        => lcd_cmd_cycle,
            data_wr_valid    => lcd_wdata_valid,
            data_wr          => lcd_wdata,

            csn              => csn,
            data_cmdn        => data_cmdn,
            wrn              => wrn,
            rdn              => rdn,
            data_lcd         => data_lcd
        );

    ----------------------------------------------------------------
    -- Формирование данных изображения
    ----------------------------------------------------------------
    rgb_test_u : rgb_test
        port map (
            clk              => clk,
            rst_n            => rst_n,
            trigger_33ms     => trigger_33ms,

            frame_upd_start  => frame_upd_start,
            -- single_upd_start => single_upd_start,
            -- x_coordinate     => x_coordinate,
            -- y_coordinate     => y_coordinate,
            write_enb        => buf_data_valid,
            data_buff        => buf_data,

            frame_end        => frame_update_int,
            sleep_off        => sleep_off,
            write_enb_ack    => buf_data_ack
        );

    ----------------------------------------------------------------
    -- Управление обновлением экрана и передачей команд LCD
    ----------------------------------------------------------------
    display_u : display
        port map (
            frame_update     => frame_update_int,

            clk              => clk,
            rst_n            => rst_n,
            trigger_33ms     => trigger_33ms,

            sleep_off        => sleep_off,
            data_bvld_ack    => buf_data_ack,

            frame_upd_start  => frame_upd_start,
            single_upd_start => single_upd_start,
            x_coordinate     => x_coordinate,
            y_coordinate     => y_coordinate,
            data_buf_valid   => buf_data_valid,
            data_buff        => buf_data,

            cmd_valid        => lcd_cmd_valid,
            cmd              => lcd_cmd,
            cmd_cycle        => lcd_cmd_cycle,
            data_wr_valid    => lcd_wdata_valid,
            data_wr          => lcd_wdata,

            ack_wr            => lcd_write_ack,
            cmd_finish        => lcd_cmd_finish,
            wrphase_finish    => lcd_wrphase_finish
        );

    ----------------------------------------------------------------
    -- Формирование периодического импульса 33 мс
    ----------------------------------------------------------------
    timer_u : timer
        port map (
            trigger_33ms => trigger_33ms,
            clk          => clk,
            rst_n        => rst_n
        );

end architecture rtl;

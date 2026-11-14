library ieee;
use ieee.std_logic_1164.all;

entity frame_buffer is
    port (
        clk              : in  std_logic;
        rst_n            : in  std_logic;

        mouse_xm         : in  std_logic_vector(8 downto 0);
        mouse_ym         : in  std_logic_vector(8 downto 0);
        mouse_btnm       : in  std_logic_vector(2 downto 0);
        mouse_tick       : in  std_logic;

        frame_upd_start  : out std_logic;
        single_upd_start : out std_logic;
        x_coordinate     : out std_logic_vector(8 downto 0);
        y_coordinate     : out std_logic_vector(8 downto 0);
        data_buf_valid   : out std_logic;
        data_buff        : out std_logic_vector(15 downto 0);

        initial_done     : in  std_logic;
        frame_update     : in  std_logic;
        data_bvld_ack    : in  std_logic
    );
end frame_buffer;

architecture rtl of frame_buffer is
    signal ram_we    : std_logic;
    signal ram_waddr : std_logic_vector(16 downto 0);
    signal ram_wdata : std_logic_vector(15 downto 0);
    signal ram_raddr : std_logic_vector(16 downto 0);
    signal ram_rdata : std_logic_vector(15 downto 0);
	 
	--  signal mouse_xm         :  std_logic_vector(8 downto 0);
	--  signal mouse_ym         :  std_logic_vector(8 downto 0);
	--  signal mouse_btnm       :  std_logic_vector(2 downto 0);
	--  signal mouse_tick       :  std_logic;

    component frame_buffer_ctrl is
        port (
        clk              : in  std_logic;
        rst_n            : in  std_logic;

        -- От мыши
        mouse_xm         : in  std_logic_vector(8 downto 0);
        mouse_ym         : in  std_logic_vector(8 downto 0);
        mouse_btnm       : in  std_logic_vector(2 downto 0);
        mouse_tick       : in  std_logic;

        -- От дисплея (обратная связь)
        initial_done     : in  std_logic;
        frame_update     : in  std_logic;
        data_bvld_ack    : in  std_logic;

        -- К дисплею (потоковый интерфейс)
        frame_upd_start  : out std_logic;
        single_upd_start : out std_logic;
        x_coordinate     : out std_logic_vector(8 downto 0);
        y_coordinate     : out std_logic_vector(8 downto 0);
        data_buf_valid   : out std_logic;
        data_buff        : out std_logic_vector(15 downto 0);

        -- К памяти
        ram_we           : out std_logic;
        ram_waddr        : out std_logic_vector(16 downto 0);
        ram_wdata        : out std_logic_vector(15 downto 0);
        ram_raddr        : out std_logic_vector(16 downto 0);
        ram_rdata        : in  std_logic_vector(15 downto 0)
    );
    end component;

    component frame_buffer_ram is
        port (
        clk   : in  std_logic;
        we    : in  std_logic;
        waddr : in  std_logic_vector(16 downto 0);
        wdata : in  std_logic_vector(15 downto 0);
        raddr : in  std_logic_vector(16 downto 0);
        rdata : out std_logic_vector(15 downto 0)
    );
    end component;

    -- component frame_buffer_test is
    --     port (
    --     clk              : in  std_logic;
    --     rst_n            : in  std_logic;

    --     mouse_xm         : out  std_logic_vector(8 downto 0);
    --     mouse_ym         : out  std_logic_vector(8 downto 0);
    --     mouse_btnm       : out  std_logic_vector(2 downto 0);
    --     mouse_tick       : out  std_logic
    -- );
    -- end component;
begin
    core_inst : frame_buffer_ctrl
        port map (
            clk              => clk,
            rst_n            => rst_n,
            mouse_xm         => mouse_xm,
            mouse_ym         => mouse_ym,
            mouse_btnm       => mouse_btnm,
            mouse_tick       => mouse_tick,
            initial_done     => initial_done,
            frame_update     => frame_update,
            data_bvld_ack    => data_bvld_ack,
            frame_upd_start  => frame_upd_start,
            single_upd_start => single_upd_start,
            x_coordinate     => x_coordinate,
            y_coordinate     => y_coordinate,
            data_buf_valid   => data_buf_valid,
            data_buff        => data_buff,
            ram_we           => ram_we,
            ram_waddr        => ram_waddr,
            ram_wdata        => ram_wdata,
            ram_raddr        => ram_raddr,
            ram_rdata        => ram_rdata
        );

    ram_inst : frame_buffer_ram
        port map (
            clk   => clk,
            we    => ram_we,
            waddr => ram_waddr,
            wdata => ram_wdata,
            raddr => ram_raddr,
            rdata => ram_rdata
        );

    -- test_inst : frame_buffer_test
    --     port map (
    --         clk              => clk,
    --         rst_n            => rst_n,
    --         mouse_xm => mouse_xm,
    --         mouse_ym => mouse_ym,
    --         mouse_btnm => mouse_btnm,
    --         mouse_tick => mouse_tick
    --     );
end rtl;
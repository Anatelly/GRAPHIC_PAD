library ieee;
use ieee.std_logic_1164.all;

entity frame_buffer is
    port (
        clk          : in  std_logic;
        rst_n        : in  std_logic;

        mouse_xm     : in  std_logic_vector(8 downto 0);
        mouse_ym     : in  std_logic_vector(8 downto 0);
        mouse_btnm   : in  std_logic_vector(2 downto 0);
        mouse_tick   : in  std_logic;
        
        rd_addr      : in  std_logic_vector(16 downto 0);
        rd_data      : out std_logic_vector(15 downto 0);
        rd_valid     : out std_logic;
        
        frame_req    : out std_logic
    );
end frame_buffer;

architecture rtl of frame_buffer is
    signal ram_we    : std_logic;
    signal ram_waddr : std_logic_vector(16 downto 0);
    signal ram_wdata : std_logic_vector(15 downto 0);
    signal ram_raddr : std_logic_vector(16 downto 0);
begin
    core_inst : entity work.frame_buffer_ctrl
        port map (
            clk          => clk,
            rst_n        => rst_n,
            mouse_xm     => mouse_xm,
            mouse_ym     => mouse_ym,
            mouse_btnm   => mouse_btnm,
            mouse_tick   => mouse_tick,
            rd_addr      => rd_addr,
            ram_we       => ram_we,
            ram_waddr    => ram_waddr,
            ram_wdata    => ram_wdata,
            ram_raddr    => ram_raddr,
            frame_req    => frame_req
        );

    ram_inst : entity work.frame_buffer_ram
        port map (
            clk   => clk,
            we    => ram_we,
            waddr => ram_waddr,
            wdata => ram_wdata,
            raddr => ram_raddr,
            rdata => rd_data
        );
        
    rd_valid <= '0'; -- Не используется в нашей интеграции
end rtl;
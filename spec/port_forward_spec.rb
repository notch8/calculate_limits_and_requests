# frozen_string_literal: true

require 'port_forward'

RSpec.describe PortForward do
  describe '.port_in_use?' do
    it 'returns true when something is listening on the port' do
      allow(TCPSocket).to receive(:new).and_return(double(close: nil))
      expect(described_class.port_in_use?(9090)).to be(true)
    end

    it 'returns false when nothing is listening on the port' do
      allow(TCPSocket).to receive(:new).and_raise(Errno::ECONNREFUSED)
      expect(described_class.port_in_use?(9090)).to be(false)
    end
  end

  describe '.wait_for_ready' do
    it 'returns immediately when port is already open' do
      allow(TCPSocket).to receive(:new).and_return(double(close: nil))
      expect { described_class.wait_for_ready(timeout: 1) }.not_to raise_error
    end

    it 'raises after timeout when port never opens' do
      allow(TCPSocket).to receive(:new).and_raise(Errno::ECONNREFUSED)
      expect { described_class.wait_for_ready(timeout: 0.1) }.to raise_error(/not ready/)
    end
  end

  describe '.start' do
    context 'when the port is already in use' do
      before { allow(described_class).to receive(:port_in_use?).and_return(true) }

      it 'raises PortInUseError before spawning anything' do
        allow(described_class).to receive(:spawn).and_call_original
        expect { described_class.start(cluster: 'my-cluster') }
          .to raise_error(PortForward::PortInUseError, /already in use/)
        expect(described_class).not_to have_received(:spawn)
      end

      it 'includes helpful instructions in the error message' do
        expect { described_class.start(cluster: 'my-cluster') }
          .to raise_error(PortForward::PortInUseError, /Stop it first/)
      end
    end

    context 'when the port is free' do
      before { allow(described_class).to receive(:port_in_use?).and_return(false) }

      it 'spawns a port-forward process with the given cluster context' do
        pid = 99_999
        allow(described_class).to receive(:spawn).and_return(pid)
        allow(Process).to receive(:detach)
        allow(described_class).to receive(:wait_for_ready)

        result = described_class.start(cluster: 'my-cluster')

        expect(described_class).to have_received(:spawn).with(
          a_string_including('--context=my-cluster'),
          out: '/dev/null', err: '/dev/null'
        )
        expect(result).to eq(pid)
      end
    end
  end
end

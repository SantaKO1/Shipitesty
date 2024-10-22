import { useBackend } from '../backend';
import {
  Button,
  ByondUi,
  LabeledList,
  Section,
  ProgressBar,
  AnimatedNumber,
  LabeledControls,
  Divider,
} from '../components';
import { Window } from '../layouts';
import { Table } from '../components/Table';
import { decodeHtmlEntities } from 'common/string';

export const BattleConsole = (_props, context) => {
  const { data } = useBackend(context);
  const { mapRef, isViewer } = data;
  return (
    <Window width={870} height={708} resizable>
      <div className="CameraConsole__left">
        <Window.Content>
          {!isViewer && <ShipControlContent />}
          <ShipContent />
          <SharedContent />
        </Window.Content>
      </div>
      <div className="CameraConsole__right">
        <div className="CameraConsole__toolbar">
          {!!data.docked && (
            <div className="NoticeBox">Ship docked to: {data.docked}</div>
          )}
        </div>
        <ByondUi
          className="CameraConsole__map"
          params={{
            id: mapRef,
            type: 'map',
          }}
        />
      </div>
    </Window>
  );
};

const SharedContent = (_props, context) => {
  const { act, data } = useBackend(context);
  const { isViewer, shipInfo = [], otherInfo = [] } = data;
  return (
    <>
      <Section
        title={
          <Button.Input
            content={decodeHtmlEntities(shipInfo.name)}
            currentValue={shipInfo.name}
            disabled={isViewer}
            onCommit={(_e, value) =>
              act('rename_ship', {
                newName: value,
              })
            }
          />
        }
        buttons={
          <>
            <Button
              tooltip="Refresh Ship Stats"
              tooltipPosition="left"
              icon="sync"
              disabled={isViewer}
              onClick={() => act('reload_ship')}
            />
            <Button // [CELADON-ADD] - Signal S.O.S - mod_celadon\wideband\code\signal.dm
              tooltip="Send S.O.S."
              tooltipPosition="left"
              icon="globe"
              disabled={isViewer}
              onClick={() => act('send_sos')}
            />
          </>
        }
      >
        <LabeledList>
          <LabeledList.Item label="Class">{shipInfo.class}</LabeledList.Item>
          <LabeledList.Item label="Sensor Range">
            <ProgressBar
              value={shipInfo.sensor_range}
              minValue={1}
              maxValue={4}
            >
              <AnimatedNumber value={shipInfo.sensor_range} />
            </ProgressBar>
            <Table.Cell>
              <Button
                tooltip="Decrease Signal Length for torpedo"
                tooltipPosition="right"
                icon="arrow-left"
                onClick={() => act('sensor_decrease')}
              />
              <Button
                tooltip="Increase Signal Length for torpedo"
                tooltipPosition="right"
                icon="arrow-right"
                onClick={() => act('sensor_increase')}
              />
            </Table.Cell>
          </LabeledList.Item>
        </LabeledList>
      </Section>
      <Section title="Radar">
        <Table>
          <Table.Row bold>
            <Table.Cell>Name</Table.Cell>
            {!isViewer && <Table.Cell>Act</Table.Cell>}
          </Table.Row>
          {otherInfo.map((ship) => (
            <Table.Row key={ship.name}>
              <Table.Cell>{ship.name}</Table.Cell>
              {!isViewer && (
                <Table.Cell>
                  <Button
                    tooltip="Interact"
                    tooltipPosition="left"
                    icon="circle"
                    disabled={
                      // I hate this so much
                      isViewer || data.speed > 0 || data.docked || data.docking
                    }
                    onClick={() =>
                      act('act_overmap', {
                        ship_to_act: ship.ref,
                      })
                    }
                  />
                </Table.Cell>
              )}
            </Table.Row>
          ))}
        </Table>
      </Section>
    </>
  );
};

// Content included on helms when they're controlling ships
const ShipContent = (_props, context) => {
  const { act, data } = useBackend(context);
  const {
    isViewer,
    engineInfo,
    estThrust,
    burnPercentage,
    speed,
    course,
    heading,
    eta,
    x,
    y,
    arpa_ships = [],
  } = data;
  return (
    <>
      <Section title="Velocity">
        <LabeledList>
          <LabeledList.Item label="Speed">
            <ProgressBar
              ranges={{
                good: [0, 4],
                average: [4, 7],
                bad: [7, Infinity],
              }}
              maxValue={10}
              value={speed}
            >
              <AnimatedNumber
                value={speed}
                // [CELADON-EDIT] - CELADON FIXES
                // format={(value) => value.toFixed(1)} // CELADON-EDIT - ORIGINAL
                format={(value) => value.toFixed(2)}
                // [/CELADON-EDIT]
              />
              Gm/s
            </ProgressBar>
          </LabeledList.Item>
          <LabeledList.Item label="Heading">
            <AnimatedNumber value={heading} />
          </LabeledList.Item>
          <LabeledList.Item label="Course">
            <AnimatedNumber value={course} />
          </LabeledList.Item>
          <LabeledList.Item label="Position">
            X
            <AnimatedNumber value={x} />
            /Y
            <AnimatedNumber value={y} />
          </LabeledList.Item>
          <LabeledList.Item label="ETA">
            <AnimatedNumber value={eta} />
          </LabeledList.Item>
        </LabeledList>
      </Section>
      <Section title="ARPA">
        {arpa_ships.map((ship) => (
          <Table.Row key={ship.name}>
            <Table.Cell>{ship.name}</Table.Cell>
            <Divider vertical divider />
            <Table.Cell>BRG:{ship.brg}°</Table.Cell>
            <Table.Cell>
              T/CPA:{ship.cpa}m {ship.tcpa}s
            </Table.Cell>
          </Table.Row>
        ))}
      </Section>
      <Section
        title="Torpedos"
        buttons={
          <Button
            tooltip="Refresh torpedos"
            tooltipPosition="left"
            icon="sync"
            disabled={isViewer}
            onClick={() => act('reload_engines')}
          />
        }
      >
        <Table>
          <Table.Row bold>
            <Table.Cell collapsing>Name</Table.Cell>
            <Table.Cell fluid>Class</Table.Cell>
          </Table.Row>
          {engineInfo &&
            engineInfo.map((engine) => (
              <Table.Row key={engine.name} className="candystripe">
                <Table.Cell name>Torpedo placeholder</Table.Cell>
                <Table.Cell>
                  content=
                  {engine.name.len < 14
                    ? engine.name
                    : engine.name.slice(0, 10) + '...'}
                </Table.Cell>
                <Table.Cell fluid>{!!engine.maxFuel}</Table.Cell>
              </Table.Row>
            ))}
        </Table>
      </Section>
    </>
  );
};

// Arrow directional controls
const ShipControlContent = (_props, context) => {
  const { act, data } = useBackend(context);
  const { burnDirection, burnPercentage, speed, estThrust, rotating } = data;
  let flyable = !data.docking && !data.docked;

  //  DIRECTIONS const idea from Lyra as part of their Haven-Urist project
  const DIRECTIONS = {
    north: 1,
    south: 2,
    east: 4,
    west: 8,
    northeast: 1 + 4,
    northwest: 1 + 8,
    southeast: 2 + 4,
    southwest: 2 + 8,
    stop: -1,
  };
  return (
    <Section
      title="Gun"
      buttons={
        <>
          <Button
            tooltip="Undock"
            tooltipPosition="left"
            icon="sign-out-alt"
            disabled={!data.docked || data.docking}
            onClick={() => act('undock')}
          />
          <Button
            tooltip="Dock in Empty Space"
            tooltipPosition="left"
            icon="sign-in-alt"
            disabled={!flyable || speed}
            onClick={() => act('dock_empty')}
          />
        </>
      }
    >
      <LabeledControls>
        <LabeledControls.Item label="Torpedo" width={'100%'}>
          <Table collapsing>
            <Table.Row height={1}>
              <Table.Cell width={1}>
                <Button
                  icon="arrow-left"
                  iconRotation={45}
                  mb={1}
                  color={rotating === -1 && 'good'}
                  disabled={!flyable}
                  onClick={() => act('rotate_left')}
                />
              </Table.Cell>
            </Table.Row>
          </Table>
        </LabeledControls.Item>
      </LabeledControls>
    </Section>
  );
};

import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { BridgeError, SqlWireValue, WireBytes, decodeBytes, encodeBytes, requireObject } from './BridgeProtocol';

interface SqlOperation {
  method?: string;
  sql?: string;
  arguments?: SqlWireValue[];
}

interface DatabaseArguments extends SqlOperation {
  id?: number;
  path?: string;
  readOnly?: boolean;
  singleInstance?: boolean;
  inTransaction?: boolean;
  transactionId?: number | null;
  operations?: SqlOperation[];
  noResult?: boolean;
  continueOnError?: boolean;
}

interface DatabaseCall {
  method: string;
  arguments?: DatabaseArguments | null;
}

interface OpenResult {
  id: number;
}

interface QueryResult {
  columns: string[];
  rows: SqlWireValue[][];
}

interface BatchError {
  code: string;
  message: string;
  data: Object | null;
}

interface BatchResult {
  result?: Object | null;
  error?: BatchError;
}

class DatabaseHandle {
  readonly id: number;
  readonly store: relationalStore.RdbStore;
  readonly singleInstance: boolean;
  transaction?: relationalStore.Transaction;

  constructor(id: number, store: relationalStore.RdbStore, singleInstance: boolean) {
    this.id = id;
    this.store = store;
    this.singleInstance = singleInstance;
  }
}

function databaseError(error: Error): BridgeError {
  if (error instanceof BridgeError) {
    return error;
  }
  return new BridgeError('sqlite_error', error.message || '原生数据库操作失败');
}

function decodeArguments(values?: SqlWireValue[]): relationalStore.ValueType[] {
  if (values === undefined || values === null) {
    return [];
  }
  if (!Array.isArray(values)) {
    throw new BridgeError('sqlite_error', 'SQL 参数必须是数组');
  }
  return values.map((value: SqlWireValue): relationalStore.ValueType => {
    if (value === null || typeof value === 'string' || typeof value === 'boolean') {
      return value;
    }
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value;
    }
    return decodeBytes(value as WireBytes);
  });
}

function encodeValue(value: relationalStore.ValueType): SqlWireValue {
  if (value === null || typeof value === 'string' || typeof value === 'boolean' || typeof value === 'number') {
    return value;
  }
  if (value instanceof Uint8Array) {
    return encodeBytes(value);
  }
  if (typeof value === 'bigint') {
    const numberValue = Number(value);
    if (Number.isSafeInteger(numberValue)) {
      return numberValue;
    }
  }
  throw new BridgeError('sqlite_error', 'SQLite 返回了无法无损传入 Web 的值');
}

export class NativeDatabase {
  private readonly context: common.Context;
  private handles: Map<number, DatabaseHandle> = new Map<number, DatabaseHandle>();
  private nextId: number = 1;
  private queue: Promise<void> = Promise.resolve();
  private closed: boolean = false;

  constructor(context: common.Context) {
    this.context = context;
  }

  invoke(value: Object): Promise<Object | null> {
    if (this.closed) {
      return Promise.reject(new BridgeError('sqlite_error', '数据库桥接已关闭'));
    }
    const call = requireObject(value) as DatabaseCall;
    // RdbStore 打开、关闭和 SQL 都进入同一队列，失败不能阻塞后续回滚。
    const result = this.queue.then(() => this.dispatch(call));
    this.queue = result.then(() => {}, () => {});
    return result.catch((error: Error) => {
      throw databaseError(error);
    });
  }

  private config(readOnly: boolean = false): relationalStore.StoreConfig {
    return {
      name: 'bugaoshan.db',
      customDir: 'arkweb',
      securityLevel: relationalStore.SecurityLevel.S2,
      isReadOnly: readOnly,
      allowRebuild: false
    };
  }

  private checkPath(path?: string): void {
    if (path !== 'bugaoshan.db' && path !== '/databases/bugaoshan.db') {
      throw new BridgeError('sqlite_error', '只允许访问应用的 bugaoshan.db 数据库');
    }
  }

  private async dispatch(call: DatabaseCall): Promise<Object | null> {
    const args: DatabaseArguments = call.arguments === undefined || call.arguments === null
      ? {} : requireObject(call.arguments) as DatabaseArguments;
    if (call.method === 'getDatabasesPath') {
      return '/databases';
    }
    if (call.method === 'openDatabase') {
      this.checkPath(args.path);
      const singleInstance = args.singleInstance !== false;
      if (singleInstance) {
        for (const handle of this.handles.values()) {
          if (handle.singleInstance) {
            const recovered: OpenResult = { id: handle.id };
            return recovered;
          }
        }
      }
      const store = await relationalStore.getRdbStore(this.context, this.config(args.readOnly === true));
      const id = this.nextId++;
      this.handles.set(id, new DatabaseHandle(id, store, singleInstance));
      const opened: OpenResult = { id: id };
      return opened;
    }
    if (call.method === 'databaseExists' || call.method === 'deleteDatabase') {
      this.checkPath(args.path);
      const exists = await fileIo.access(this.context.databaseDir + '/rdb/arkweb/bugaoshan.db');
      if (call.method === 'databaseExists') {
        return exists;
      }
      for (const handle of this.handles.values()) {
        await this.closeHandle(handle);
      }
      if (exists) {
        await relationalStore.deleteRdbStore(this.context, this.config());
      }
      return null;
    }
    const handle = args.id === undefined ? undefined : this.handles.get(args.id);
    if (handle === undefined) {
      throw new BridgeError('sqlite_error', '数据库句柄无效或已关闭');
    }
    if (call.method === 'closeDatabase') {
      await this.closeHandle(handle);
      return null;
    }
    if (call.method === 'batch') {
      return this.batch(handle, args);
    }
    return this.runSql(handle, call.method, args);
  }

  private async runSql(handle: DatabaseHandle, method: string, operation: SqlOperation): Promise<Object | null> {
    const sql = operation.sql;
    if (typeof sql !== 'string' || sql.trim().length === 0) {
      throw new BridgeError('sqlite_error', 'SQL 不能为空');
    }
    const parameters = decodeArguments(operation.arguments);
    const statement = sql.trim().replace(/;$/, '').trim().toUpperCase();
    if (method === 'execute' && /^BEGIN(?: (?:EXCLUSIVE|IMMEDIATE|DEFERRED))?(?: TRANSACTION)?$/.test(statement)) {
      if (handle.transaction !== undefined) {
        throw new BridgeError('sqlite_error', '不支持嵌套数据库事务');
      }
      let type = relationalStore.TransactionType.DEFERRED;
      if (statement.includes('EXCLUSIVE')) {
        type = relationalStore.TransactionType.EXCLUSIVE;
      } else if (statement.includes('IMMEDIATE')) {
        type = relationalStore.TransactionType.IMMEDIATE;
      }
      handle.transaction = await handle.store.createTransaction({ transactionType: type });
      // 不返回 transactionId，让 sqflite 继续使用已有的 Dart 事务锁。
      return null;
    }
    if (method === 'execute' && /^(?:COMMIT|END|ROLLBACK)(?: TRANSACTION)?$/.test(statement)) {
      const transaction = handle.transaction;
      if (transaction === undefined) {
        throw new BridgeError('sqlite_error', '当前没有活动事务');
      }
      if (statement.startsWith('ROLLBACK')) {
        await transaction.rollback();
      } else {
        await transaction.commit();
      }
      handle.transaction = undefined;
      return null;
    }
    if (method === 'query') {
      const resultSet = handle.transaction === undefined
        ? await handle.store.querySql(sql, parameters)
        : await handle.transaction.querySql(sql, parameters);
      try {
        const result: QueryResult = { columns: resultSet.columnNames, rows: [] };
        while (resultSet.goToNextRow()) {
          const row: SqlWireValue[] = [];
          for (let index = 0; index < result.columns.length; index++) {
            row.push(encodeValue(resultSet.getValue(index)));
          }
          result.rows.push(row);
        }
        return result;
      } finally {
        resultSet.close();
      }
    }
    if (method !== 'execute' && method !== 'insert' && method !== 'update') {
      throw new BridgeError('unsupported_method', '不支持的 sqflite 方法: ' + method);
    }
    const value = handle.transaction === undefined
      ? await handle.store.execute(sql, parameters)
      : await handle.transaction.execute(sql, parameters);
    if (method === 'execute') {
      return null;
    }
    const result = encodeValue(value);
    if (typeof result !== 'number') {
      throw new BridgeError('sqlite_error', 'SQL 写入没有返回行号或影响行数');
    }
    // RdbStore 在 INSERT OR IGNORE 没有插入数据时返回 -1。
    return method === 'insert' && result === -1 ? null : result;
  }

  private async batch(handle: DatabaseHandle, args: DatabaseArguments): Promise<Object | null> {
    if (!Array.isArray(args.operations)) {
      throw new BridgeError('sqlite_error', '批处理 operations 必须是数组');
    }
    const results: BatchResult[] = [];
    for (const operation of args.operations) {
      try {
        requireObject(operation);
        const result = await this.runSql(handle, operation.method || '', operation);
        if (args.noResult !== true) {
          results.push({ result: result });
        }
      } catch (error) {
        const failure = databaseError(error as Error);
        if (args.continueOnError !== true) {
          throw failure;
        }
        if (args.noResult !== true) {
          results.push({ error: { code: failure.code, message: failure.message, data: null } });
        }
      }
    }
    return args.noResult === true ? null : results;
  }

  private async closeHandle(handle: DatabaseHandle): Promise<void> {
    try {
      if (handle.transaction !== undefined) {
        await handle.transaction.rollback();
        handle.transaction = undefined;
      }
    } finally {
      await handle.store.close();
      this.handles.delete(handle.id);
    }
  }

  async dispose(): Promise<void> {
    this.closed = true;
    await this.queue;
    let failure: BridgeError | undefined = undefined;
    for (const handle of this.handles.values()) {
      try {
        await this.closeHandle(handle);
      } catch (error) {
        failure = databaseError(error as Error);
      }
    }
    if (failure !== undefined) {
      throw failure;
    }
  }
}

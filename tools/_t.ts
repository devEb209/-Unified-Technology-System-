type EntityState = "abstract"|"material"|"transient";
interface Relation { id:string }
interface RrwEvent { id:string }
export interface RrwSerialized {
  v: 1;
  entities: Array<{
    id: string;
    components: Array<[string, unknown]>;
    compressed: Array<[string, unknown]> | null;
    state: EntityState;
    data: unknown;
  }>;
  relations: Array<Omit<Relation, 'id'> & { id: unknown }>;
  eventLog: Array<Omit<RrwEvent, 'id'> & { id: unknown }>;
  entEvents: Array<[string, Array<Omit<RrwEvent, 'id'> & { id: unknown }>]>;
  processTargets: Array<[string, string[]]>;
}
console.log(1);
